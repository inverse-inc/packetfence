package main

import (
	"bufio"
	"context"
	"encoding/binary"
	"encoding/json"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"sync"
	"syscall"

	"github.com/Sereal/Sereal/Go/sereal"
)

type Request struct {
	Method           string `json:"method"`
	Key              string `json:"key"`
	NoLastTouchCache string `json:"no_last_touch_cache"`
	Encoding         string `json:"encoding"`
	LastKey          string `json:"last_key"`
	Search           string `json:"search"`
	Namespace        string `json:"namespace"`
	Light            string `json:"light"`
	Index            int    `json:"index"`
}

const (
	goPfconfigSocketPath   = "/usr/local/pf/var/run/pfconfig-go.sock"
	perlPfconfigSocketPath = "/usr/local/pf/var/run/pfconfig.sock"
)

func main() {
	var err error
	ctx := context.Background()
	logger := slog.Default()
	slog.SetLogLoggerLevel(slog.LevelDebug)

	// Manage graceful shutdown
	stopSig := make(chan os.Signal, 1)
	signal.Notify(stopSig, os.Interrupt, syscall.SIGTERM, syscall.SIGQUIT, syscall.SIGABRT)

	logger.InfoContext(ctx, "Starting server on UNIX socket...")
	_ = os.Remove(goPfconfigSocketPath)
	l, err := net.Listen("unix", goPfconfigSocketPath)
	if err != nil {
		logger.ErrorContext(ctx, err.Error())
	}
	defer l.Close() //nolint:errcheck
	logger.InfoContext(ctx, "... started!")
	runServer(ctx, logger, stopSig, l)
	logger.InfoContext(ctx, "Closing, waiting for connection to close...")
	logger.InfoContext(ctx, "... closed!")
}

func runServer(ctx context.Context, logger *slog.Logger, stopSig chan os.Signal, l net.Listener) {
	var wg sync.WaitGroup
	for loop := true; loop; {
		reqConn, err := l.Accept()
		if err != nil {
			logger.ErrorContext(ctx, err.Error())
			continue
		}
		logger.InfoContext(ctx, "connection", "addr", reqConn.RemoteAddr())
		wg.Go(func() {
			defer reqConn.Close() //nolint:errcheck
			scanner := bufio.NewScanner(reqConn)
			var wgProxy sync.WaitGroup
			for scanner.Scan() {
				data := scanner.Text()
				var request Request
				err := json.Unmarshal([]byte(data), &request)
				if err != nil {
					logger.ErrorContext(ctx, err.Error())
					continue
				}
				logger.InfoContext(ctx, "got a request")
				wgProxy.Go(func() {
					proxyRequest(ctx, logger, reqConn, request)
				})
			}
			if err := scanner.Err(); err != nil {
				logger.ErrorContext(ctx, err.Error())
			}
			wgProxy.Wait()
		})
		select {
		case <-stopSig:
			logger.InfoContext(ctx, "stopping signal")
			loop = false
		default:
		}
	}
	wg.Wait()
}

func proxyRequest(ctx context.Context, logger *slog.Logger, reqConn net.Conn, request Request) {
	var header [4]byte
	// Not used now but we intercept the request
	output, err := json.Marshal(request)
	if err != nil {
		logger.InfoContext(ctx, "jsonmarshal", "err", err.Error())
		return
	}
	output = append(output, '\n')
	// Proxy the request to pfconfig Perl
	c, err := net.Dial("unix", perlPfconfigSocketPath)
	if err != nil {
		logger.InfoContext(ctx, "dial", "err", err.Error())
		return
	}
	defer c.Close() //nolint:errcheck
	logger.InfoContext(ctx, "dial ok")
	binary.LittleEndian.PutUint32(header[:], uint32(len(output)))
	n, err := c.Write(header[:])
	if n != len(header) || err != nil {
		logger.InfoContext(ctx, "write header 1", "err", err.Error())
		return
	}
	n, err = c.Write(output)
	if n != len(output) || err != nil {
		logger.InfoContext(ctx, "write output 1", "err", err.Error())
		return
	}
	// Read config from pfconfig Perl
	response := make([]byte, 0, 1024*32)
	n, err = c.Read(response)
	if err != nil {
		logger.InfoContext(ctx, "read response", "err", err.Error())
		return
	}
	logger.InfoContext(ctx, "read response", "len(response)", n)
	// Send response back to service
	binary.LittleEndian.PutUint32(header[:], uint32(len(response)))
	n, err = reqConn.Write(header[:])
	if n != len(header) || err != nil {
		logger.InfoContext(ctx, "write back header", "err", err.Error())
		return
	}
	n, err = reqConn.Write(response)
	if n != len(response) || err != nil {
		logger.InfoContext(ctx, "write back respo se", "err", err.Error())
		return
	}
}

func test() {
	_ = sereal.NewEncoderV3()
}
