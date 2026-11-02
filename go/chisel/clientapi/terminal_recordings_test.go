package clientapi

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
)

// newRecordingsTestServer serves the recordings routes over dir.
func newRecordingsTestServer(t *testing.T, dir string, running bool) *httptest.Server {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	api := &API{ctx: ctx, terminalRecording: terminalRecordingConfig{Enabled: true, Dir: dir}}
	if running {
		api.serverRunning = 1
	}
	router := chi.NewRouter()
	mountTerminalRecordingRoutes(router, api)
	server := httptest.NewServer(router)
	t.Cleanup(server.Close)
	return server
}

// record writes a small session with the real recorder and returns its file name.
func record(t *testing.T, dir, session, admin string, outputs ...string) string {
	t.Helper()
	rec, err := newAsciicastRecorder(terminalRecordingConfig{Enabled: true, Dir: dir}, "c1", session, admin)
	if err != nil {
		t.Fatal(err)
	}
	if len(outputs) > 0 {
		rec.Resize(120, 40)
	}
	for _, out := range outputs {
		rec.Output([]byte(out))
	}
	rec.Close()
	return filepath.Base(rec.Path())
}

func TestTerminalRecordingsList(t *testing.T) {
	dir := t.TempDir()
	first := record(t, dir, "0b1f6b9a-7f5c-4a3e-9c2d-1e2f3a4b5c6d", "admin@example.com", "$ ls\r\n", "a b c\r\n")
	// A header-only file (session closed before any output) and junk that
	// must not be listed.
	empty := record(t, dir, "11111111-2222-3333-4444-555555555555", "")
	os.WriteFile(filepath.Join(dir, "notes.txt"), []byte("x"), 0o600)
	os.WriteFile(filepath.Join(dir, "../escape.cast"), []byte("x"), 0o600)
	os.Mkdir(filepath.Join(dir, "20250101T000000Z-dir.cast"), 0o700)

	server := newRecordingsTestServer(t, dir, false)
	res, err := http.Get(server.URL + "/terminal-recordings")
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		t.Fatalf("status %d", res.StatusCode)
	}
	var out struct {
		Enabled    bool                `json:"enabled"`
		Recordings []terminalRecording `json:"recordings"`
	}
	if err := json.NewDecoder(res.Body).Decode(&out); err != nil {
		t.Fatal(err)
	}
	if !out.Enabled {
		t.Error("enabled should be reported")
	}
	if len(out.Recordings) != 2 {
		t.Fatalf("got %d recordings, want 2: %+v", len(out.Recordings), out.Recordings)
	}
	// newest first: both were written within the same second at worst, so
	// find them by name instead of position.
	byName := map[string]terminalRecording{}
	for _, r := range out.Recordings {
		byName[r.Name] = r
	}
	f := byName[first]
	if f.Session != "0b1f6b9a-7f5c-4a3e-9c2d-1e2f3a4b5c6d" || f.AdminUser != "admin@example.com" {
		t.Errorf("session/admin not parsed: %+v", f)
	}
	if f.Width != 80 || f.Height != 24 || f.StartedAt == "" || f.Size == 0 {
		t.Errorf("header not parsed: %+v", f)
	}
	if f.DurationSeconds <= 0 {
		t.Errorf("duration should come from the last event: %+v", f)
	}
	if f.InProgress {
		t.Errorf("no terminal is running, nothing is in progress: %+v", f)
	}
	e := byName[empty]
	if e.DurationSeconds != 0 || e.AdminUser != "" {
		t.Errorf("header-only recording: %+v", e)
	}
	for _, r := range out.Recordings {
		if r.Name > out.Recordings[0].Name {
			t.Errorf("not sorted newest first: %v", out.Recordings)
		}
	}
}

func TestTerminalRecordingsListMissingDir(t *testing.T) {
	server := newRecordingsTestServer(t, filepath.Join(t.TempDir(), "none"), false)
	res, err := http.Get(server.URL + "/terminal-recordings")
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	body, _ := io.ReadAll(res.Body)
	if res.StatusCode != http.StatusOK || !strings.Contains(string(body), `"recordings":[]`) {
		t.Fatalf("status %d body %s, want 200 with an empty list", res.StatusCode, body)
	}
}

func TestTerminalRecordingsInProgress(t *testing.T) {
	dir := t.TempDir()
	name := record(t, dir, "s1", "", "x")
	server := newRecordingsTestServer(t, dir, true)
	res, err := http.Get(server.URL + "/terminal-recordings")
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	var out struct {
		Recordings []terminalRecording `json:"recordings"`
	}
	json.NewDecoder(res.Body).Decode(&out)
	if len(out.Recordings) != 1 || out.Recordings[0].Name != name || !out.Recordings[0].InProgress {
		t.Fatalf("a just-written file while the terminal runs should be in progress: %+v", out.Recordings)
	}
}

func TestTerminalRecordingServe(t *testing.T) {
	dir := t.TempDir()
	name := record(t, dir, "0b1f6b9a-7f5c-4a3e-9c2d-1e2f3a4b5c6d", "admin", "hello\r\n")
	server := newRecordingsTestServer(t, dir, false)

	res, err := http.Get(server.URL + "/terminal-recordings/" + name)
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(res.Body)
	res.Body.Close()
	if res.StatusCode != http.StatusOK {
		t.Fatalf("status %d: %s", res.StatusCode, body)
	}
	if ct := res.Header.Get("Content-Type"); !strings.HasPrefix(ct, "application/x-asciicast") {
		t.Errorf("content type %q", ct)
	}
	if res.Header.Get("Content-Disposition") != "" {
		t.Errorf("no attachment without ?download: %q", res.Header.Get("Content-Disposition"))
	}
	want, _ := os.ReadFile(filepath.Join(dir, name))
	if string(body) != string(want) {
		t.Fatalf("body differs from the file:\n%s\n---\n%s", body, want)
	}

	res, err = http.Get(server.URL + "/terminal-recordings/" + name + "?download=1")
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if cd := res.Header.Get("Content-Disposition"); cd != `attachment; filename="`+name+`"` {
		t.Errorf("content disposition %q", cd)
	}

	for _, bad := range []string{"missing.cast", "20250101T000000Z-x.cast", "..%2Fescape.cast", "notes.txt"} {
		res, err := http.Get(server.URL + "/terminal-recordings/" + bad)
		if err != nil {
			t.Fatal(err)
		}
		res.Body.Close()
		if res.StatusCode != http.StatusNotFound && res.StatusCode != http.StatusBadRequest {
			t.Errorf("%s: status %d, want 400/404", bad, res.StatusCode)
		}
	}
}

func TestLastEventTimeSkipsPartialLine(t *testing.T) {
	dir := t.TempDir()
	name := record(t, dir, "s", "", "a", "b")
	path := filepath.Join(dir, name)
	// Append a half-written event (a crash mid-write).
	f, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0o600)
	f.WriteString(`[99.5, "o", "trunc`)
	f.Close()
	info, _ := os.Stat(path)
	rec := describeRecording(path, info)
	if rec.DurationSeconds <= 0 || rec.DurationSeconds >= 99 {
		t.Fatalf("duration %v should come from the last complete event", rec.DurationSeconds)
	}
}
