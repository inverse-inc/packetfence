package clientapi

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/gorilla/websocket"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/nxadm/tail"
)

const (
	// logsMaxBackfill caps the ?lines=N initial read.
	logsMaxBackfill     = 1000
	logsDefaultBackfill = 100
	// logsPingPeriod must stay under haproxy-admin's `timeout server` (90s)
	// or the proxied stream is cut on idle log files.
	logsPingPeriod   = 30 * time.Second
	logsWriteTimeout = 10 * time.Second
	logsReadTimeout  = 90 * time.Second
	// logsMaxLineBytes bounds a single log line during backfill; longer
	// lines are skipped rather than growing the scanner buffer unbounded.
	logsMaxLineBytes = 64 * 1024
)

// logFiles is the allowlist of streamable logs: UI key -> in-container path.
// The service logs are produced by the s6 tee pipelines
// (containers/pfconnector-remote/rootfs/etc/s6-overlay/s6-rc.d/<svc>-log);
// upgrade.log is written by the host-side upgrade script through the conf
// bind mount.
var logFiles = map[string]string{
	"pfconnector-client":   "/usr/local/pf/logs/pfconnector-client.log",
	"radiusd-auth":         "/usr/local/pf/logs/radiusd-auth.log",
	"fingerbank-collector": "/usr/local/pf/logs/fingerbank-collector.log",
	"connector-cache":      "/usr/local/pf/logs/connector-cache.log",
	"upgrade":              "/usr/local/pf/conf/upgrade.log",
}

// logsEnabled mirrors PFCONNECTOR_LOGS (default true): whether the log
// streaming endpoint is available on this connector.
func logsEnabled() bool {
	value := strings.ToLower(strings.TrimSpace(os.Getenv("PFCONNECTOR_LOGS")))
	if enabled, found := sharedutils.ISENABLED[value]; found {
		return enabled
	}
	return true
}

// availableLogFiles returns the allowlist keys whose file exists right now,
// sorted for a stable UI. Reported in /system/info as the capability flag the
// admin UI keys the "View Logs" button on (older connectors omit the field).
func availableLogFiles(api *API) []string {
	if !api.LogsEnabled {
		return nil
	}
	keys := []string{}
	for key, path := range logFiles {
		if _, err := os.Stat(path); err == nil {
			keys = append(keys, key)
		}
	}
	sort.Strings(keys)
	return keys
}

// logEvent is one streamed log line. The shape matches the central
// log-tailer's events ({raw, meta}) so the admin UI can reuse its log
// rendering utilities.
type logEvent struct {
	Raw  string        `json:"raw"`
	Meta logEventsMeta `json:"meta"`
}

type logEventsMeta struct {
	Filename string `json:"filename"`
}

var logsUpgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 4096,
	// The central aaa layer already authorized the request (CONNECTORS_READ)
	// and this port only accepts loopback peers, so the Origin the browser
	// sent to the central server is irrelevant here.
	CheckOrigin: func(r *http.Request) bool { return true },
}

// readLastNLines returns up to n trailing lines of fileName. Lines longer
// than logsMaxLineBytes abort the scan (the tail that was collected so far is
// returned) instead of growing memory unbounded.
func readLastNLines(fileName string, n int) ([]string, error) {
	file, err := os.Open(fileName)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 64*1024), logsMaxLineBytes)
	lines := make([]string, 0, n)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
		if len(lines) > n {
			lines = lines[1:]
		}
	}
	if err := scanner.Err(); err != nil && err != bufio.ErrTooLong {
		return nil, err
	}
	return lines, nil
}

// tailLog streams an allowlisted log file over a websocket: an initial
// backfill of the last ?lines=N lines, then a live follow. One tailer per
// connection; the stream ends when the client goes away, the file cannot be
// tailed, or the API shuts down.
//
// Note: the backfill reads last-N then the follow starts at EOF, so lines
// written between the two can be missed. Acceptable for a live viewer.
func tailLog(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !api.LogsEnabled {
			http.Error(w, "Log streaming is not enabled on this connector", http.StatusForbidden)
			return
		}

		name := chi.URLParam(r, "name")
		path, exists := logFiles[name]
		if !exists {
			http.Error(w, fmt.Sprintf("Unknown log file %q", name), http.StatusNotFound)
			return
		}
		if _, err := os.Stat(path); err != nil {
			http.Error(w, fmt.Sprintf("Log file %q is not available on this connector", name), http.StatusNotFound)
			return
		}

		lines := logsDefaultBackfill
		if raw := r.URL.Query().Get("lines"); raw != "" {
			if n, err := strconv.Atoi(raw); err == nil && n >= 0 {
				lines = n
			}
		}
		if lines > logsMaxBackfill {
			lines = logsMaxBackfill
		}

		ws, err := logsUpgrader.Upgrade(w, r, nil)
		if err != nil {
			// Upgrade already replied to the client.
			log.LoggerWContext(api.ctx).Warn(fmt.Sprintf("logs: websocket upgrade failed for %s: %v", name, err))
			return
		}
		defer ws.Close()

		writeEvent := func(raw string) error {
			payload, err := json.Marshal(logEvent{Raw: raw, Meta: logEventsMeta{Filename: name}})
			if err != nil {
				return err
			}
			ws.SetWriteDeadline(time.Now().Add(logsWriteTimeout))
			return ws.WriteMessage(websocket.TextMessage, payload)
		}
		closeWith := func(code int, reason string) {
			ws.SetWriteDeadline(time.Now().Add(logsWriteTimeout))
			ws.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(code, reason))
		}

		if lines > 0 {
			backfill, err := readLastNLines(path, lines)
			if err != nil {
				closeWith(websocket.CloseInternalServerErr, fmt.Sprintf("cannot read %s", name))
				return
			}
			for _, line := range backfill {
				if err := writeEvent(line); err != nil {
					return
				}
			}
		}

		// Poll:true so truncation by the host logrotate copytruncate policy
		// is detected and the follow restarts from the new beginning.
		t, err := tail.TailFile(path, tail.Config{
			Follow:    true,
			ReOpen:    true,
			Poll:      true,
			MustExist: true,
			Location:  &tail.SeekInfo{Whence: io.SeekEnd},
			Logger:    tail.DiscardingLogger,
		})
		if err != nil {
			closeWith(websocket.CloseInternalServerErr, fmt.Sprintf("cannot tail %s", name))
			return
		}
		defer func() {
			t.Stop()
			t.Cleanup()
		}()

		// Read pump: the client never sends data frames; its ReadMessage
		// error (close, timeout, network) is the disconnect signal.
		clientGone := make(chan struct{})
		go func() {
			defer close(clientGone)
			ws.SetReadDeadline(time.Now().Add(logsReadTimeout))
			ws.SetPongHandler(func(string) error {
				ws.SetReadDeadline(time.Now().Add(logsReadTimeout))
				return nil
			})
			for {
				if _, _, err := ws.ReadMessage(); err != nil {
					return
				}
			}
		}()

		pings := time.NewTicker(logsPingPeriod)
		defer pings.Stop()

		for {
			select {
			case line, ok := <-t.Lines:
				if !ok {
					closeWith(websocket.CloseNormalClosure, "log tail ended")
					return
				}
				if line.Err != nil {
					closeWith(websocket.CloseInternalServerErr, fmt.Sprintf("tail error on %s", name))
					return
				}
				if err := writeEvent(line.Text); err != nil {
					return
				}
			case <-pings.C:
				ws.SetWriteDeadline(time.Now().Add(logsWriteTimeout))
				if err := ws.WriteMessage(websocket.PingMessage, nil); err != nil {
					return
				}
			case <-clientGone:
				return
			case <-r.Context().Done():
				return
			case <-api.ctx.Done():
				closeWith(websocket.CloseGoingAway, "connector shutting down")
				return
			}
		}
	})
}
