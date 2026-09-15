package clientapi

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"log"
	"os"
	"os/exec"
	"os/user"
	"strings"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/creack/pty"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/sorenisanerd/gotty/server"
)

// randomToken returns n random bytes as hex.
func randomToken(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		log.Fatal("Unable to generate the terminal credential:", err)
	}
	return hex.EncodeToString(b)
}

// BashFactory builds the bash slaves served by gotty. activity is the shared
// last-activity clock (unix nanos) that the idle watcher in enableTerminal
// reads; every pty read/write bumps it. Every slave (one per websocket
// connection) is recorded as an asciicast when recording is enabled.
type BashFactory struct {
	activity    *atomic.Int64
	recording   terminalRecordingConfig
	connectorID string
	// session is the activation uuid of the current terminal session and
	// adminUser the PacketFence admin who activated it, set by the lifecycle
	// goroutine on StartProcessing; they identify the recording.
	session   atomic.Value
	adminUser atomic.Value
}

// setSession records the activation the next slaves belong to.
func (factory *BashFactory) setSession(id, adminUser string) {
	factory.session.Store(id)
	factory.adminUser.Store(adminUser)
}

func (factory *BashFactory) currentSession() string {
	if v, ok := factory.session.Load().(string); ok {
		return v
	}
	return ""
}

func (factory *BashFactory) currentAdminUser() string {
	if v, ok := factory.adminUser.Load().(string); ok {
		return v
	}
	return ""
}

func (factory *BashFactory) Name() string {
	return "bash"
}

func (factory *BashFactory) New(params map[string][]string) (server.Slave, error) {
	argv := []string{"bash"}
	if _, exists := params["arg"]; exists {
		argv = append(argv, params["arg"]...)
	}

	cmd := exec.Command(argv[0], argv[1:]...)
	cmd.Env = append(os.Environ(), "TERM=xterm-256color")

	if usr, err := user.Current(); err == nil {
		cmd.Dir = usr.HomeDir
	}

	// Fail closed: when recording is on, a shell without its transcript is
	// refused rather than silently unrecorded.
	var recorder *asciicastRecorder
	if factory.recording.Enabled {
		var err error
		recorder, err = newAsciicastRecorder(factory.recording, factory.connectorID, factory.currentSession(), factory.currentAdminUser())
		if err != nil {
			log.Printf("Refusing the terminal session: %v", err)
			return nil, err
		}
		log.Printf("Recording terminal session to %s", recorder.Path())
	}

	ptmx, err := pty.Start(cmd)
	if err != nil {
		if recorder != nil {
			recorder.Close()
		}
		return nil, err
	}

	return &BashSlave{
		command:  cmd,
		pty:      ptmx,
		activity: factory.activity,
		recorder: recorder,
	}, nil
}

type BashSlave struct {
	command  *exec.Cmd
	pty      *os.File
	activity *atomic.Int64
	// recorder is nil when recording is disabled.
	recorder *asciicastRecorder
}

// touch records terminal activity for the idle-timeout watcher.
func (slave *BashSlave) touch() {
	if slave.activity != nil {
		slave.activity.Store(time.Now().UnixNano())
	}
}

func (slave *BashSlave) WindowTitleVariables() map[string]interface{} {
	return map[string]interface{}{
		"command": strings.Join(slave.command.Args, " "),
		"pid":     slave.command.Process.Pid,
	}
}

func (slave *BashSlave) ResizeTerminal(width int, height int) error {
	if slave.recorder != nil {
		slave.recorder.Resize(width, height)
	}
	return pty.Setsize(slave.pty, &pty.Winsize{
		Rows: uint16(height),
		Cols: uint16(width),
	})
}

func (slave *BashSlave) Write(data []byte) (int, error) {
	slave.touch()
	if slave.recorder != nil {
		slave.recorder.Input(data)
	}
	return slave.pty.Write(data)
}

func (slave *BashSlave) Read(data []byte) (int, error) {
	n, err := slave.pty.Read(data)
	if n > 0 {
		slave.touch()
		if slave.recorder != nil {
			slave.recorder.Output(data[:n])
		}
	}
	return n, err
}

func (slave *BashSlave) Close() error {
	if slave.command != nil && slave.command.Process != nil {
		slave.command.Process.Signal(syscall.SIGTERM)
	}
	err := slave.pty.Close()
	if slave.recorder != nil {
		slave.recorder.Close()
	}
	return err
}

func (api *API) terminal() (bool, error) {

	// Options for the GoTTY server
	options := &server.Options{
		PermitWrite:     true,
		Address:         "127.0.0.1",
		Port:            "8022",
		EnableReconnect: true,
		ReconnectTime:   10,
		MaxConnection:   0,
		// Credential is set per activation (StartProcessing below).
		EnableBasicAuth: true,
		Credential:      "",
		EnableTLS:       false,
		TitleFormat:     "pfconnector-remote",
		Once:            false,
		PermitArguments: false,
		Width:           0,
		Height:          0,
		WSOrigin:        ".*", // Regular expression to accept all origins
	}

	// Create the custom factory
	factory := &BashFactory{
		activity:    api.terminalActivity,
		recording:   api.terminalRecording,
		connectorID: api.ConnectorId,
	}
	if factory.recording.Enabled {
		log.Printf("Terminal sessions are recorded (asciicast) under %s (input recorded: %v)", factory.recording.Dir, factory.recording.RecordInput)
	} else {
		log.Println("PFCONNECTOR_TERMINAL_RECORD is disabled: terminal sessions are not recorded")
	}

	// Create the GoTTY server
	gottyServer, err := server.New(factory, options)
	if err != nil {
		log.Fatal("Error creating GoTTY server:", err)
	}
	api.gottyOptions = options

	var serverCtx context.Context
	var serverCancel context.CancelFunc

	go func() {
		defer log.Println("Command handler stopped")

		for {
			select {
			case msg := <-api.commandChan:
				switch msg.Type {
				case StartProcessing:
					if atomic.LoadInt32(&api.serverRunning) == 1 {
						log.Println("GoTTY server is already running")
						break
					}

					atomic.StoreInt32(&api.serverRunning, 1)
					factory.setSession(msg.Session, msg.AdminUser)
					// Fresh credential for this activation: gotty reads it
					// when Run starts (basic auth) and on every websocket
					// handshake (auth token); the proxy in client_api.go
					// presents it, so a local process without it is refused.
					api.terminalCredMu.Lock()
					options.Credential = "pfconnector:" + randomToken(24)
					api.terminalCredMu.Unlock()

					serverCtx, serverCancel = context.WithCancel(api.ctx)

					go func() {
						defer func() {
							atomic.StoreInt32(&api.serverRunning, 0)
							log.Println("GoTTY server stopped")
						}()

						log.Println("Starting GoTTY server on localhost:8022")
						if err := gottyServer.Run(serverCtx); err != nil {
							log.Printf("Error running GoTTY server: %v", err)
						}
					}()

				case StopProcessing:
					if atomic.LoadInt32(&api.serverRunning) == 0 {
						log.Println("GoTTY server is not running")
						break
					}

					log.Println("Stopping GoTTY server...")
					if serverCancel != nil {
						serverCancel()
					}
				}

			case <-api.ctx.Done():
				log.Println("Command handler shutting down...")
				if serverCancel != nil {
					serverCancel()
				}
				return
			}
		}
	}()

	time.Sleep(time.Millisecond * 100)

	PFCONNECTOR_TERMINAL := os.Getenv("PFCONNECTOR_TERMINAL")
	if !sharedutils.IsEnabled(PFCONNECTOR_TERMINAL) {
		log.Println("PFCONNECTOR_TERMINAL is not enabled")
		return false, nil
	}

	log.Println("PFCONNECTOR_TERMINAL is enabled")

	// gotty is NOT started here: it only comes up when an authorized
	// activation (one-time session uuid + TOTP code) reaches enableTerminal.
	// Starting it at boot would expose a shell through the tunnel proxy
	// without any activation.
	return true, nil
}
