package clientapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/gorilla/websocket"
)

// newLogsTestServer serves tailLog on /logs/{name} with the allowlist
// swapped for a temp file, and returns the ws:// URL for it.
func newLogsTestServer(t *testing.T, logPath string) (*httptest.Server, string) {
	t.Helper()

	saved := logFiles
	logFiles = map[string]string{"test": logPath}
	t.Cleanup(func() { logFiles = saved })

	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	api := &API{ctx: ctx, LogsEnabled: true}

	router := chi.NewRouter()
	router.Get("/logs/{name}", tailLog(api))
	server := httptest.NewServer(router)
	t.Cleanup(server.Close)

	return server, "ws" + strings.TrimPrefix(server.URL, "http")
}

func readEvent(t *testing.T, ws *websocket.Conn) logEvent {
	t.Helper()
	ws.SetReadDeadline(time.Now().Add(5 * time.Second))
	_, payload, err := ws.ReadMessage()
	if err != nil {
		t.Fatalf("reading event: %v", err)
	}
	var event logEvent
	if err := json.Unmarshal(payload, &event); err != nil {
		t.Fatalf("decoding event %q: %v", payload, err)
	}
	return event
}

func TestTailLogUnknownOrMissingFile(t *testing.T) {
	logPath := filepath.Join(t.TempDir(), "test.log")
	server, _ := newLogsTestServer(t, logPath)

	// Allowlisted key whose file does not exist yet
	res, err := http.Get(server.URL + "/logs/test")
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusNotFound {
		t.Errorf("missing file: expected 404, got %d", res.StatusCode)
	}

	// Key outside the allowlist, even as a valid path
	res, err = http.Get(server.URL + "/logs/passwd")
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusNotFound {
		t.Errorf("unknown key: expected 404, got %d", res.StatusCode)
	}
}

func TestTailLogBackfillAndFollow(t *testing.T) {
	logPath := filepath.Join(t.TempDir(), "test.log")
	content := ""
	for i := 1; i <= 20; i++ {
		content += fmt.Sprintf("line %d\n", i)
	}
	if err := os.WriteFile(logPath, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	_, wsURL := newLogsTestServer(t, logPath)

	ws, _, err := websocket.DefaultDialer.Dial(wsURL+"/logs/test?lines=5", nil)
	if err != nil {
		t.Fatalf("websocket dial: %v", err)
	}
	defer ws.Close()

	// Backfill: the last 5 lines, one frame each, in order
	for i := 16; i <= 20; i++ {
		event := readEvent(t, ws)
		if want := fmt.Sprintf("line %d", i); event.Raw != want {
			t.Fatalf("backfill: expected %q, got %q", want, event.Raw)
		}
		if event.Meta.Filename != "test" {
			t.Fatalf("backfill: expected meta.filename \"test\", got %q", event.Meta.Filename)
		}
	}

	// Follow: a line appended after the stream started is delivered live.
	// Small delay so the tailer is seeked to EOF before the write.
	time.Sleep(300 * time.Millisecond)
	f, err := os.OpenFile(logPath, os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.WriteString("line 21\n"); err != nil {
		t.Fatal(err)
	}
	f.Close()

	if event := readEvent(t, ws); event.Raw != "line 21" {
		t.Fatalf("follow: expected \"line 21\", got %q", event.Raw)
	}
}

func TestTailLogTruncateDetection(t *testing.T) {
	logPath := filepath.Join(t.TempDir(), "test.log")
	if err := os.WriteFile(logPath, []byte("old 1\nold 2\n"), 0644); err != nil {
		t.Fatal(err)
	}
	_, wsURL := newLogsTestServer(t, logPath)

	ws, _, err := websocket.DefaultDialer.Dial(wsURL+"/logs/test?lines=0", nil)
	if err != nil {
		t.Fatalf("websocket dial: %v", err)
	}
	defer ws.Close()

	// Simulate logrotate copytruncate, then write fresh content: the Poll
	// tailer must detect the truncation and stream from the new beginning.
	time.Sleep(300 * time.Millisecond)
	if err := os.Truncate(logPath, 0); err != nil {
		t.Fatal(err)
	}
	time.Sleep(300 * time.Millisecond)
	f, err := os.OpenFile(logPath, os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.WriteString("fresh 1\n"); err != nil {
		t.Fatal(err)
	}
	f.Close()

	if event := readEvent(t, ws); event.Raw != "fresh 1" {
		t.Fatalf("after truncate: expected \"fresh 1\", got %q", event.Raw)
	}
}

func TestTailLogDisabled(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	api := &API{ctx: ctx, LogsEnabled: false}
	router := chi.NewRouter()
	router.Get("/logs/{name}", tailLog(api))
	disabled := httptest.NewServer(router)
	defer disabled.Close()

	res, err := http.Get(disabled.URL + "/logs/test")
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusForbidden {
		t.Errorf("logs disabled: expected 403, got %d", res.StatusCode)
	}
}

func TestAvailableLogFiles(t *testing.T) {
	dir := t.TempDir()
	saved := logFiles
	logFiles = map[string]string{
		"present": filepath.Join(dir, "present.log"),
		"absent":  filepath.Join(dir, "absent.log"),
	}
	t.Cleanup(func() { logFiles = saved })
	if err := os.WriteFile(logFiles["present"], []byte(""), 0644); err != nil {
		t.Fatal(err)
	}

	api := &API{LogsEnabled: true}
	if got := availableLogFiles(api); len(got) != 1 || got[0] != "present" {
		t.Errorf("expected [present], got %v", got)
	}

	api.LogsEnabled = false
	if got := availableLogFiles(api); got != nil {
		t.Errorf("logs disabled: expected nil, got %v", got)
	}
}
