package main

import (
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"sync"
	"syscall"

	"github.com/Sereal/Sereal/Go/sereal"
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/cache"
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/manager"
)

const (
	goPfconfigSocketPath   = "/usr/local/pf/var/run/pfconfig-go.sock"
	perlPfconfigSocketPath = "/usr/local/pf/var/run/pfconfig.sock"
	confFolder             = "/usr/local/pf/conf"
)

type CmdArgs struct {
	Proto string // tcp or udp
	Port  string // for tcp
}

func processArgs() (*CmdArgs, error) {
	proto := flag.String("proto", "unix", "Protocol for the socket")
	port := flag.String("port", "44444", "Port for TCP socket")
	flag.Parse()
	if *proto != "unix" && *proto != "tcp" {
		return nil, fmt.Errorf("invalid proto %s", *proto)
	}
	return &CmdArgs{Proto: *proto, Port: *port}, nil
}

func usageAndExit(err error) {
	fmt.Fprintf(os.Stderr, "error: %s\n", err.Error())
	flag.Usage()
	os.Exit(1)
}

func main() {
	var err error
	ctx := context.Background()
	logger := slog.Default()
	slog.SetLogLoggerLevel(slog.LevelDebug)
	cmdArgs, err := processArgs()
	if err != nil {
		usageAndExit(err)
	}
	// Manage graceful shutdown
	stopSig := make(chan os.Signal, 1)
	signal.Notify(stopSig, os.Interrupt,
		syscall.SIGTERM, syscall.SIGQUIT, syscall.SIGABRT, syscall.SIGINT)
	{
		logger.InfoContext(ctx, "Preloading all configuration files...")
		cache := cache.NewShardedCache[string, any](32, 64, cache.HashString)
		defer cache.Close()
		manager := manager.NewManager(logger, confFolder, cache)
		if err = manager.LoadConfigs(ctx); err != nil {
			logger.ErrorContext(ctx, err.Error())
			os.Exit(1)
		}
		logger.InfoContext(ctx, "... done!")
		logger.InfoContext(ctx, fmt.Sprintf("Starting server on %s socket...", cmdArgs.Proto))
		var l net.Listener
		if cmdArgs.Proto == "tcp" {
			l, err = net.Listen("tcp", "0.0.0.0:"+cmdArgs.Port)
		} else {
			_ = os.Remove(goPfconfigSocketPath)
			l, err = net.Listen("unix", goPfconfigSocketPath)
		}
		if err != nil {
			logger.ErrorContext(ctx, err.Error())
			os.Exit(1)
		}
		defer l.Close() //nolint:errcheck
		logger.InfoContext(ctx, "... now listenning on "+l.Addr().Network()+" socket "+l.Addr().String())
		var wg sync.WaitGroup
		wg.Go(func() {
			<-stopSig
			logger.InfoContext(ctx, "interrupted")
			l.Close() //nolint:errcheck
		})
		wg.Go(func() {
			if err := runServer(ctx, logger, l, manager); err != nil {
				logger.ErrorContext(ctx, "server stopped", "err", err.Error())
			}
			// TODO: stopSig goroutine
		})
		wg.Wait()
		logger.InfoContext(ctx, "Server stopped!")
	}
}

func runServer(ctx context.Context, logger *slog.Logger, l net.Listener, m *manager.Manager) error {
	var wg sync.WaitGroup
	defer wg.Wait()
	for {
		reqConn, err := l.Accept()
		if err != nil {
			return err
		}
		//logger.InfoContext(ctx, "new connection")
		wg.Go(func() {
			defer reqConn.Close() //nolint:errcheck
			if err := manageRequest(ctx, logger, reqConn, m); err != nil {
				logger.ErrorContext(ctx, "request", "addr", reqConn.RemoteAddr(), "err", err.Error())
				return
			}
		})
	}
}

func manageRequest(ctx context.Context, logger *slog.Logger, c net.Conn, m *manager.Manager) error {
	// read the request
	data, err := readRequest(c)
	if err != nil {
		return err
	}
	// parse the request
	var request manager.Request
	if err = json.Unmarshal(data, &request); err != nil {
		logger.ErrorContext(ctx, err.Error())
		return err
	}
	// logger.InfoContext(ctx, "new request", "req", request)
	// Treat the request in the new pfconfig
	response, err := m.Process(ctx, request)
	if err != nil {
		if errors.Is(err, errors.ErrUnsupported) {
			// Proxy the request to pfconfig Perl
			logger.InfoContext(ctx, "proxy")
			return proxyRequest(ctx, logger, c, data)
		}
		logger.ErrorContext(ctx, "process", "err", err.Error())
		return err
	}
	return sendResponse(c, request.Encoding, response)
}

func sendResponse(c net.Conn, encoding string, response any) error {
	if encoding == "json" {
		// TODO: not used by pf?
		data, err := json.Marshal(response)
		if err != nil {
			return err
		}
		if n, err := c.Write(data); err != nil {
			return err
		} else if n != len(data) {
			return errors.New("sent less bytes than expected (json)")
		}
	} else {
		enc := sereal.NewEncoderV5()
		enc.PerlCompat = true
		jr, err := enc.Marshal(response)
		if err != nil {
			return err
		}
		var header [4]byte
		binary.LittleEndian.PutUint32(header[:], uint32(len(jr)))
		if n, err := c.Write(header[:]); err != nil {
			return err
		} else if n != len(header) {
			return errors.New("sent less bytes than expected (sereal header)")
		}
		if n, err := c.Write(jr); err != nil {
			return err
		} else if n != len(jr) {
			return errors.New("sent less bytes than expected (sereal)")
		}
	}
	return nil
}

func readRequest(c net.Conn) ([]byte, error) {
	const bufSize = 1024
	data := make([]byte, 0, bufSize)
	buf := make([]byte, bufSize)
	for {
		n, err := c.Read(buf[:])
		if err != nil {
			if err == io.EOF {
				break
			}
			return nil, err
		}
		data = append(data, buf[:n]...)
		if n < bufSize {
			break
		}
	}
	return data, nil
}

func proxyRequest(ctx context.Context, logger *slog.Logger, reqConn net.Conn, data []byte) error {
	c, err := net.Dial("unix", perlPfconfigSocketPath)
	if err != nil {
		logger.InfoContext(ctx, "dial", "err", err.Error())
		return err
	}
	defer c.Close() //nolint:errcheck
	n, err := c.Write(data)
	if err != nil {
		logger.ErrorContext(ctx, "proxy request to perl pfconfig", "err", err.Error())
		return err
	}
	if n != len(data) {
		logger.ErrorContext(ctx, "proxy request to perl pfconfig", "err", "sent less bytes than expected")
		return err
	}
	// fast proxy
	_, err = io.Copy(reqConn, c)
	if err != nil {
		logger.ErrorContext(ctx, "proxy request from perl pfconfig to service", "err", err.Error())
		return err
	}
	return nil
}
