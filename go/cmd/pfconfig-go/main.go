package main

import (
	"bufio"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"runtime/debug"
	"sync"
	"syscall"
	"time"

	"github.com/Sereal/Sereal/Go/sereal"
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/cache"
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
		cache := cache.NewShardedCache[string, any](32, 64, cache.HashString)
		defer cache.Close()
		manager := manager.NewManager(logger, confFolder, cache)
		if err := manager.LoadConfigs(ctx); err != nil {
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
		//logger.InfoContext(ctx, "new connection")
		wg.Go(func() {
			defer reqConn.Close() //nolint:errcheck
			// a bug in a request must not take the whole config service down
			defer func() {
				if r := recover(); r != nil {
					logger.ErrorContext(ctx, "request panic", "panic", r, "stack", string(debug.Stack()))
				}
			}()
			if err := manageRequest(ctx, logger, reqConn, m); err != nil {
				logger.ErrorContext(ctx, "request", "addr", reqConn.RemoteAddr(), "err", err.Error())
				return
			}
		})
	}
}

// requestTimeout is the time a client has to send its request, same as the Perl server
const requestTimeout = 5 * time.Second

// maxRequestSize bounds the request line
const maxRequestSize = 64 * 1024

// readRequest reads the request line, the Perl client sends a single JSON line
// and keeps the connection open while waiting for the answer.
func readRequest(reqConn net.Conn) ([]byte, error) {
	if err := reqConn.SetReadDeadline(time.Now().Add(requestTimeout)); err != nil {
		return nil, err
	}
	r := bufio.NewReader(io.LimitReader(reqConn, maxRequestSize))
	data, err := r.ReadBytes('\n')
	if err != nil && !(errors.Is(err, io.EOF) && len(data) > 0) {
		return nil, fmt.Errorf("read request: %w", err)
	}
	return data, reqConn.SetReadDeadline(time.Time{})
}

func manageRequest(ctx context.Context, logger *slog.Logger, reqConn net.Conn, m *manager.Manager) error {
	data, err := readRequest(reqConn)
	if err != nil {
		return err
	}
	// parse the request
	var request manager.Request
	if err := json.Unmarshal(data, &request); err != nil {
		return fmt.Errorf("decode request: %w", err)
	}
	// Treat the request in the new pfconfig
	element, err := m.Process(ctx, request)
	if err != nil {
		if errors.Is(err, errors.ErrUnsupported) {
			// Proxy the request to pfconfig Perl
			return proxyRequest(ctx, logger, reqConn, data)
		}
		// Like the Perl server, always answer: on error the client gets an undef element.
		// Closing without an answer makes the Perl client retry then die.
		logger.ErrorContext(ctx, "process", "key", request.Key, "method", request.Method, "err", err.Error())
		element = map[string]any{}
	}
	payload, err := encodeResponse(request.Encoding, element)
	if err != nil {
		return err
	}
	var header [4]byte
	binary.LittleEndian.PutUint32(header[:], uint32(len(payload)))
	if _, err := reqConn.Write(header[:]); err != nil {
		return err
	}
	_, err = reqConn.Write(payload)
	return err
}

// encodeResponse encodes the answer in the encoding requested by the client:
// the Perl clients use sereal (default), the Go clients (pfconfigdriver) use json.
func encodeResponse(encoding string, element any) ([]byte, error) {
	switch encoding {
	case "", "sereal":
		enc := sereal.NewEncoderV5()
		enc.PerlCompat = true
		return enc.Marshal(element)
	case "json":
		return json.Marshal(element)
	default:
		return nil, fmt.Errorf("unknown encoding '%s'", encoding)
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
