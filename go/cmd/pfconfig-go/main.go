package main

import (
	"context"
	"encoding/binary"
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
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/cache"
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/loader"
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/manager"
)

const (
	goPfconfigSocketPath   = "/usr/local/pf/var/run/pfconfig-go.sock"
	perlPfconfigSocketPath = "/usr/local/pf/var/run/pfconfig.sock"
	confFolder             = "/usr/local/pf/conf"
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
		logger.InfoContext(ctx, "Preloading all configuration files...")
		cache := cache.NewShardedCache[string, *loader.Conf](64, 128, cache.HashString)
		defer cache.Close()
		manager := manager.NewManager(confFolder, cache)
		if err := manager.LoadConfigs(ctx, logger); err != nil {
			logger.ErrorContext(ctx, err.Error())
			os.Exit(1)
		}
		logger.InfoContext(ctx, "... done!")
		logger.InfoContext(ctx, "Starting server on UNIX socket...")
		_ = os.Remove(goPfconfigSocketPath)
		l, err := net.Listen("unix", goPfconfigSocketPath)
		if err != nil {
			logger.ErrorContext(ctx, err.Error())
			os.Exit(1)
		}
		defer l.Close() //nolint:errcheck
		logger.InfoContext(ctx, "... now listenning on socket "+goPfconfigSocketPath)
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
		wg.Go(func() {
			defer reqConn.Close() //nolint:errcheck
			if err := manageRequest(ctx, logger, reqConn, m); err != nil {
				logger.ErrorContext(ctx, "request", "addr", reqConn.RemoteAddr(), "err", err.Error())
				return
			}
		})
	}
}

func manageRequest(ctx context.Context, logger *slog.Logger, reqConn net.Conn, m *manager.Manager) error {
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
	// parse the request
	var request manager.Request
	err := json.Unmarshal(data, &request)
	if err != nil {
		logger.ErrorContext(ctx, err.Error())
		return err
	}
	// Treat the request in the new pfconfig
	element, err := m.Process(ctx, logger, request)
	if err != nil {
		if errors.Is(err, errors.ErrUnsupported) {
			// Proxy the request to pfconfig Perl
			logger.InfoContext(ctx, "proxy")
			return proxyRequest(ctx, logger, reqConn, data)
		}
		logger.ErrorContext(ctx, "process", "err", err.Error())
		return err
	}
	enc := sereal.NewEncoderV5()
	enc.PerlCompat = true
	jr, err := enc.Marshal(element)
	if err != nil {
		logger.ErrorContext(ctx, "process", "err", err.Error())
		return err
	}
	var header [4]byte
	binary.LittleEndian.PutUint32(header[:], uint32(len(jr)))
	if n, err := reqConn.Write(header[:]); err != nil {
		return err
	} else if n != len(header) {
		return errors.New("sent less bytes than expected")
	}
	if n, err := reqConn.Write(jr); err != nil {
		return err
	} else if n != len(jr) {
		return errors.New("sent less bytes than expected")
	}
	return nil
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
