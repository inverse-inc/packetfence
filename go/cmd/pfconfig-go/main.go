package main

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"sync"
	"syscall"

	"github.com/Sereal/Sereal/Go/sereal"
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/namespace"
	"gopkg.in/ini.v1"
)

const (
	goPfconfigSocketPath   = "/usr/local/pf/var/run/pfconfig-go.sock"
	perlPfconfigSocketPath = "/usr/local/pf/var/run/pfconfig.sock"
)

func main() {
	ctx := context.Background()
	logger := slog.Default()
	slog.SetLogLoggerLevel(slog.LevelDebug)

	// Manage graceful shutdown
	stopSig := make(chan os.Signal, 1)
	signal.Notify(stopSig, os.Interrupt,
		syscall.SIGTERM, syscall.SIGQUIT, syscall.SIGABRT, syscall.SIGINT)

	{
		logger.InfoContext(ctx, "Starting server on UNIX socket...")
		_ = os.Remove(goPfconfigSocketPath)
		l, err := net.Listen("unix", goPfconfigSocketPath)
		if err != nil {
			logger.ErrorContext(ctx, err.Error())
			os.Exit(1)
		}
		defer l.Close() //nolint:errcheck
		go func() {
			<-stopSig
			logger.InfoContext(ctx, "interrupted")
			l.Close() //nolint:errcheck
		}()
		logger.InfoContext(ctx, "... now listenning on socket "+goPfconfigSocketPath)
		_ = runServer(ctx, logger, l)
	}

	logger.InfoContext(ctx, "Server stopped!")
}

func runServer(ctx context.Context, logger *slog.Logger, l net.Listener) error {
	var wg sync.WaitGroup
	defer wg.Wait()
	for {
		reqConn, err := l.Accept()
		if err != nil {
			logger.ErrorContext(ctx, err.Error())
			return err
		}
		logger.InfoContext(ctx, "connection", "addr", reqConn.RemoteAddr())
		wg.Go(func() {
			defer reqConn.Close() //nolint:errcheck
			if err := manageRequest(ctx, logger, reqConn); err != nil {
				logger.ErrorContext(ctx, err.Error())
				return
			}
		})
	}
}

func manageRequest(ctx context.Context, logger *slog.Logger, reqConn net.Conn) error {
	// read the request
	const bufSize = 1024
	data := make([]byte, 0, bufSize)
	buf := make([]byte, bufSize)
	for {
		n, err := reqConn.Read(buf[:])
		if err != nil {
			if err == io.EOF {
				break
			}
			logger.ErrorContext(ctx, err.Error())
			return err
		}
		data = append(data, buf[:n]...)
		if n < bufSize {
			break
		}
	}
	var request namespace.Request
	err := json.Unmarshal(data, &request)
	if err != nil {
		logger.ErrorContext(ctx, err.Error())
		return err
	}
	// Treat the request in the new pfconfig
	err = namespace.Manage(ctx, logger, reqConn, request)
	if errors.Is(err, errors.ErrUnsupported) {
		// Proxy the request to pfconfig Perl
		return proxyRequest(ctx, logger, reqConn, data)
	} else {
		return err
	}
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
		logger.ErrorContext(ctx, "proxy request toperl  pfconfig", "err", "wrote less bytes than request size")
		return err
	}
	// fast proxy
	_, err = io.Copy(reqConn, c)
	if err != nil {
		logger.ErrorContext(ctx, "proxy direct copy perl pfconfig to service", "err", err.Error())
		return err
	}
	return nil
}

func test() {
	_ = sereal.NewEncoderV3()
	_ = ini.DefaultSection
}
