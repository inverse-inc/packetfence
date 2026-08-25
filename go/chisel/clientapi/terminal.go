package clientapi

import (
	"context"
	"fmt"
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

// BashFactory builds the bash slaves served by gotty. activity is the shared
// last-activity clock (unix nanos) that the idle watcher in enableTerminal
// reads; every pty read/write bumps it.
type BashFactory struct {
	activity *atomic.Int64
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

	ptmx, err := pty.Start(cmd)
	if err != nil {
		return nil, err
	}

	return &BashSlave{
		command:  cmd,
		pty:      ptmx,
		activity: factory.activity,
	}, nil
}

type BashSlave struct {
	command  *exec.Cmd
	pty      *os.File
	activity *atomic.Int64
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
	return pty.Setsize(slave.pty, &pty.Winsize{
		Rows: uint16(height),
		Cols: uint16(width),
	})
}

func (slave *BashSlave) Write(data []byte) (int, error) {
	slave.touch()
	return slave.pty.Write(data)
}

func (slave *BashSlave) Read(data []byte) (int, error) {
	n, err := slave.pty.Read(data)
	if n > 0 {
		slave.touch()
	}
	return n, err
}

func (slave *BashSlave) Close() error {
	if slave.command != nil && slave.command.Process != nil {
		slave.command.Process.Signal(syscall.SIGTERM)
	}
	return slave.pty.Close()
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
		EnableBasicAuth: false,
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
	factory := &BashFactory{activity: api.terminalActivity}

	// Create the GoTTY server
	gottyServer, err := server.New(factory, options)
	if err != nil {
		log.Fatal("Error creating GoTTY server:", err)
	}

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

	select {
	case api.commandChan <- Message{Type: StartProcessing}:
		log.Println("Start command sent successfully")
	case <-time.After(time.Second * 5):
		return false, fmt.Errorf("timeout sending start command")
	}

	return true, nil
}
