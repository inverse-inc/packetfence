package clientapi

import (
	"context"
	"errors"
	"log"
	"os"
	"os/exec"
	"os/user"
	"strings"
	"syscall"

	"github.com/creack/pty"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/sorenisanerd/gotty/server"
)

type BashFactory struct{}

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
		command: cmd,
		pty:     ptmx,
	}, nil
}

type BashSlave struct {
	command *exec.Cmd
	pty     *os.File
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
	return slave.pty.Write(data)
}

func (slave *BashSlave) Read(data []byte) (int, error) {
	return slave.pty.Read(data)
}

func (slave *BashSlave) Close() error {
	if slave.command != nil && slave.command.Process != nil {
		slave.command.Process.Signal(syscall.SIGTERM)
	}
	return slave.pty.Close()
}

func (api *API) terminal() (bool, error) {
	PFCONNECTOR_TERMINAL := os.Getenv("PFCONNECTOR_TERMINAL")
	if !sharedutils.IsEnabled(PFCONNECTOR_TERMINAL) {
		return false, errors.New("PFCONNECTOR_TERMINAL is not enabled")
	}
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
	factory := &BashFactory{}

	// Create the GoTTY server
	gottyServer, err := server.New(factory, options)
	if err != nil {
		log.Fatal("Error creating GoTTY server:", err)
	}
	go func() {
		for {
			select {
			case msg := <-api.commandChan:
				switch msg.Type {
				case StartProcessing:
					go func() {
						log.Println("Starting GoTTY server on localhost:8022")
						if err := gottyServer.Run(context.Background()); err != nil {
							log.Printf("Error starting GoTTY server: %v", err)
						}
					}()
				case StopProcessing:

				}
			}
		}
	}()
	return true, nil
}
