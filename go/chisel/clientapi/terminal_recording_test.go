package clientapi

import (
	"bufio"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
	"unicode/utf8"
)

// readCast parses an asciicast v2 file into its header and event lines.
func readCast(t *testing.T, path string) (asciicastHeader, [][]interface{}) {
	t.Helper()
	f, err := os.Open(path)
	if err != nil {
		t.Fatalf("open recording: %v", err)
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	if !scanner.Scan() {
		t.Fatal("recording is empty")
	}
	var header asciicastHeader
	if err := json.Unmarshal(scanner.Bytes(), &header); err != nil {
		t.Fatalf("header is not JSON: %v (%q)", err, scanner.Text())
	}
	var events [][]interface{}
	for scanner.Scan() {
		if !utf8.Valid(scanner.Bytes()) {
			t.Fatalf("event line is not valid UTF-8: %q", scanner.Bytes())
		}
		var ev []interface{}
		if err := json.Unmarshal(scanner.Bytes(), &ev); err != nil {
			t.Fatalf("event is not JSON: %v (%q)", err, scanner.Text())
		}
		if len(ev) != 3 {
			t.Fatalf("event has %d fields, want 3: %q", len(ev), scanner.Text())
		}
		events = append(events, ev)
	}
	if err := scanner.Err(); err != nil {
		t.Fatalf("scan: %v", err)
	}
	return header, events
}

func TestAsciicastRecorderWritesV2(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "terminal")
	cfg := terminalRecordingConfig{Enabled: true, RecordInput: false, Dir: dir}

	rec, err := newAsciicastRecorder(cfg, "connector-1", "0b1f6b9a-7f5c-4a3e-9c2d-1e2f3a4b5c6d")
	if err != nil {
		t.Fatalf("newAsciicastRecorder: %v", err)
	}
	rec.Resize(120, 40)
	rec.Output([]byte("root@remote:~# "))
	rec.Input([]byte("ls\r")) // input recording is off: must not appear
	rec.Output([]byte("ls\r\nfile\r\n"))
	if err := rec.Close(); err != nil {
		t.Fatalf("Close: %v", err)
	}

	info, err := os.Stat(rec.Path())
	if err != nil {
		t.Fatalf("recording not created: %v", err)
	}
	if perm := info.Mode().Perm(); perm != 0o600 {
		t.Errorf("recording mode = %o, want 600", perm)
	}
	if !strings.HasSuffix(rec.Path(), "-0b1f6b9a-7f5c-4a3e-9c2d-1e2f3a4b5c6d.cast") {
		t.Errorf("recording name does not carry the session: %s", rec.Path())
	}
	if dinfo, err := os.Stat(dir); err != nil || dinfo.Mode().Perm() != 0o700 {
		t.Errorf("recordings dir mode/err = %v/%v, want 700", dinfo.Mode().Perm(), err)
	}

	header, events := readCast(t, rec.Path())
	if header.Version != 2 || header.Width != defaultRecordingWidth || header.Height != defaultRecordingHeight || header.Timestamp == 0 {
		t.Errorf("unexpected header: %+v", header)
	}
	if !strings.Contains(header.Title, "connector-1") {
		t.Errorf("title lacks the connector id: %q", header.Title)
	}

	want := [][2]string{{"r", "120x40"}, {"o", "root@remote:~# "}, {"o", "ls\r\nfile\r\n"}}
	if len(events) != len(want) {
		t.Fatalf("got %d events, want %d: %v", len(events), len(want), events)
	}
	var last float64 = -1
	for i, ev := range events {
		ts, ok := ev[0].(float64)
		if !ok || ts < last {
			t.Errorf("event %d: timestamp %v not monotonic", i, ev[0])
		}
		last = ts
		if ev[1] != want[i][0] || ev[2] != want[i][1] {
			t.Errorf("event %d = %v, want %v", i, ev[1:], want[i])
		}
	}
}

func TestAsciicastRecorderInputOptIn(t *testing.T) {
	cfg := terminalRecordingConfig{Enabled: true, RecordInput: true, Dir: t.TempDir()}
	rec, err := newAsciicastRecorder(cfg, "c", "s")
	if err != nil {
		t.Fatal(err)
	}
	rec.Input([]byte("id\r"))
	rec.Close()
	_, events := readCast(t, rec.Path())
	if len(events) != 1 || events[0][1] != "i" || events[0][2] != "id\r" {
		t.Errorf("input event not recorded: %v", events)
	}
}

// A multi-byte rune split across two pty reads must yield valid UTF-8 in
// the file, and nothing pending must be lost at close.
func TestAsciicastRecorderSplitUTF8(t *testing.T) {
	cfg := terminalRecordingConfig{Enabled: true, Dir: t.TempDir()}
	rec, err := newAsciicastRecorder(cfg, "c", "s")
	if err != nil {
		t.Fatal(err)
	}
	text := []byte("é→✓")          // 2 + 3 + 3 bytes
	rec.Output(text[:1])           // half of é: nothing complete yet
	rec.Output(text[1:4])          // é complete, → cut after 2 bytes
	rec.Output(text[4:7])          // → complete, ✓ cut after 1 byte
	rec.Output(text[7:])           // ✓ complete
	rec.Output([]byte("\xe2\x9c")) // dangling at close
	rec.Close()

	_, events := readCast(t, rec.Path())
	var got strings.Builder
	for _, ev := range events {
		if ev[1] != "o" {
			t.Fatalf("unexpected event %v", ev)
		}
		got.WriteString(ev[2].(string))
	}
	// The complete runes come out intact; the dangling tail is replaced.
	if !strings.HasPrefix(got.String(), "é→✓") {
		t.Errorf("reassembled output = %q, want prefix %q", got.String(), "é→✓")
	}
	if strings.Count(got.String(), "�") == 0 {
		t.Errorf("dangling partial rune at close was dropped: %q", got.String())
	}
}

func TestSplitIncompleteUTF8(t *testing.T) {
	cases := []struct {
		in, complete, tail string
	}{
		{"", "", ""},
		{"abc", "abc", ""},
		{"é", "é", ""},
		{"a\xc3", "a", "\xc3"},                 // 2-byte start, missing 1
		{"a\xe2\x86", "a", "\xe2\x86"},         // 3-byte start, missing 1
		{"a\xf0\x9f\x98", "a", "\xf0\x9f\x98"}, // 4-byte start, missing 1
		{"a\xff", "a\xff", ""},                 // invalid start byte: nothing to wait for
		{"\x80\x80\x80", "\x80\x80\x80", ""},   // stray continuation bytes
	}
	for _, c := range cases {
		complete, tail := splitIncompleteUTF8([]byte(c.in))
		if string(complete) != c.complete || string(tail) != c.tail {
			t.Errorf("split(%q) = %q,%q want %q,%q", c.in, complete, tail, c.complete, c.tail)
		}
	}
}

func TestAsciicastRecorderNameCollision(t *testing.T) {
	cfg := terminalRecordingConfig{Enabled: true, Dir: t.TempDir()}
	a, err := newAsciicastRecorder(cfg, "c", "same")
	if err != nil {
		t.Fatal(err)
	}
	b, err := newAsciicastRecorder(cfg, "c", "same")
	if err != nil {
		t.Fatal(err)
	}
	if a.Path() == b.Path() {
		t.Errorf("two recordings of the same session in the same second share a path: %s", a.Path())
	}
	a.Close()
	b.Close()

	// A session id that is not a plain token is not trusted in a file name.
	c, err := newAsciicastRecorder(cfg, "c", "../evil")
	if err != nil {
		t.Fatal(err)
	}
	c.Close()
	if !strings.HasSuffix(c.Path(), "-unknown.cast") || filepath.Dir(c.Path()) != cfg.Dir {
		t.Errorf("unsafe session id leaked into the path: %s", c.Path())
	}
}

func TestAsciicastRecorderUnwritableDir(t *testing.T) {
	file := filepath.Join(t.TempDir(), "not-a-dir")
	if err := os.WriteFile(file, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	cfg := terminalRecordingConfig{Enabled: true, Dir: file}
	if _, err := newAsciicastRecorder(cfg, "c", "s"); err == nil {
		t.Error("expected an error when the recordings dir cannot be created")
	}
}

func TestTerminalRecordingConfigFromEnv(t *testing.T) {
	t.Setenv("PFCONNECTOR_TERMINAL_RECORD", "")
	t.Setenv("PFCONNECTOR_TERMINAL_RECORD_INPUT", "")
	t.Setenv("PFCONNECTOR_TERMINAL_RECORDINGS_DIR", "")
	cfg := terminalRecordingConfigFromEnv()
	if !cfg.Enabled || cfg.RecordInput || cfg.Dir != defaultTerminalRecordingsDir {
		t.Errorf("defaults = %+v", cfg)
	}

	t.Setenv("PFCONNECTOR_TERMINAL_RECORD", "false")
	t.Setenv("PFCONNECTOR_TERMINAL_RECORD_INPUT", "yes")
	t.Setenv("PFCONNECTOR_TERMINAL_RECORDINGS_DIR", "/tmp/x")
	cfg = terminalRecordingConfigFromEnv()
	if cfg.Enabled || !cfg.RecordInput || cfg.Dir != "/tmp/x" {
		t.Errorf("overrides = %+v", cfg)
	}

	// Garbage keeps the default rather than silently disabling recording.
	t.Setenv("PFCONNECTOR_TERMINAL_RECORD", "maybe")
	if !terminalRecordingConfigFromEnv().Enabled {
		t.Error("unknown value disabled recording")
	}
}

// The factory records every slave it builds when recording is on, and
// refuses the shell when the recording cannot be created.
func TestBashFactoryRecording(t *testing.T) {
	dir := t.TempDir()
	factory := &BashFactory{
		recording:   terminalRecordingConfig{Enabled: true, Dir: dir},
		connectorID: "c",
	}
	factory.setSession("sess-1")
	slave, err := factory.New(map[string][]string{})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	bs := slave.(*BashSlave)
	if bs.recorder == nil {
		t.Fatal("slave has no recorder")
	}
	if err := slave.ResizeTerminal(100, 30); err != nil {
		t.Fatalf("ResizeTerminal: %v", err)
	}
	if err := slave.Close(); err != nil {
		t.Fatalf("Close: %v", err)
	}
	entries, err := os.ReadDir(dir)
	if err != nil || len(entries) != 1 {
		t.Fatalf("recordings in %s = %v (%v), want 1", dir, entries, err)
	}
	if !strings.Contains(entries[0].Name(), "-sess-1.cast") {
		t.Errorf("recording name %q lacks the session", entries[0].Name())
	}
	_, events := readCast(t, filepath.Join(dir, entries[0].Name()))
	found := false
	for _, ev := range events {
		if ev[1] == "r" && ev[2] == "100x30" {
			found = true
		}
	}
	if !found {
		t.Errorf("resize event missing: %v", events)
	}

	file := filepath.Join(t.TempDir(), "file")
	os.WriteFile(file, nil, 0o600)
	broken := &BashFactory{recording: terminalRecordingConfig{Enabled: true, Dir: file}}
	if _, err := broken.New(map[string][]string{}); err == nil {
		t.Error("expected the shell to be refused when recording fails")
	}

	off := &BashFactory{recording: terminalRecordingConfig{Enabled: false, Dir: file}}
	s, err := off.New(map[string][]string{})
	if err != nil {
		t.Fatalf("New with recording off: %v", err)
	}
	if s.(*BashSlave).recorder != nil {
		t.Error("recorder created while recording is off")
	}
	s.Close()
}

// End to end through a real bash: what the shell printed ends up in the
// recording as "o" events, in order.
func TestBashSlaveRecordsRealShell(t *testing.T) {
	dir := t.TempDir()
	factory := &BashFactory{recording: terminalRecordingConfig{Enabled: true, Dir: dir}, connectorID: "c"}
	factory.setSession("e2e")
	slave, err := factory.New(map[string][]string{"arg": {"--norc", "--noprofile"}})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if err := slave.ResizeTerminal(80, 24); err != nil {
		t.Fatalf("ResizeTerminal: %v", err)
	}
	if _, err := slave.Write([]byte("echo recorded-$((40+2))\n")); err != nil {
		t.Fatalf("Write: %v", err)
	}
	// Read until the command's output shows up (or the pty closes).
	var seen strings.Builder
	buf := make([]byte, 4096)
	deadline := make(chan struct{})
	go func() {
		for !strings.Contains(seen.String(), "recorded-42") {
			n, err := slave.Read(buf)
			if n > 0 {
				seen.Write(buf[:n])
			}
			if err != nil {
				break
			}
		}
		close(deadline)
	}()
	select {
	case <-deadline:
	case <-time.After(10 * time.Second):
		t.Fatalf("bash output never arrived; saw %q", seen.String())
	}
	slave.Write([]byte("exit\n"))
	if err := slave.Close(); err != nil {
		t.Fatalf("Close: %v", err)
	}

	entries, _ := os.ReadDir(dir)
	if len(entries) != 1 {
		t.Fatalf("want 1 recording, got %v", entries)
	}
	_, events := readCast(t, filepath.Join(dir, entries[0].Name()))
	var out strings.Builder
	for _, ev := range events {
		switch ev[1] {
		case "o":
			out.WriteString(ev[2].(string))
		case "i":
			t.Errorf("input recorded while PFCONNECTOR_TERMINAL_RECORD_INPUT is off: %v", ev)
		}
	}
	if !strings.Contains(out.String(), "recorded-42") {
		t.Errorf("shell output missing from the recording: %q", out.String())
	}
	if events[0][1] != "r" || events[0][2] != "80x24" {
		t.Errorf("first event should be the resize, got %v", events[0])
	}
}
