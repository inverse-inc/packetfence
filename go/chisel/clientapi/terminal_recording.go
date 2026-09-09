package clientapi

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/inverse-inc/go-utils/sharedutils"
)

// Terminal session recording, asciicast v2
// (https://docs.asciinema.org/manual/asciicast/v2/): one file per gotty
// connection under the recordings directory, replayable with `asciinema play`
// or the asciinema web player.
//
// The file lives under /usr/local/pf/logs, the host's
// /usr/local/pfconnector-remote/logs bind mount, so it survives container
// restarts and upgrades. Retention is not handled here (yet).

const (
	// defaultTerminalRecordingsDir is the in-container recordings directory.
	defaultTerminalRecordingsDir = "/usr/local/pf/logs/terminal"
	// Terminal size assumed until the browser sends its first resize; the
	// real size follows as an "r" event so players pick it up immediately.
	defaultRecordingWidth  = 80
	defaultRecordingHeight = 24
	// pendingUTF8Max bounds the incomplete multi-byte tail carried between
	// pty reads (a rune is at most 4 bytes).
	pendingUTF8Max = utf8.UTFMax - 1
)

// recordingSessionName restricts the session id used in the file name.
var recordingSessionName = regexp.MustCompile(`^[A-Za-z0-9_.-]{1,64}$`)

// terminalRecordingConfig is the recording policy read from the environment.
type terminalRecordingConfig struct {
	// Enabled mirrors PFCONNECTOR_TERMINAL_RECORD (default true).
	Enabled bool
	// RecordInput mirrors PFCONNECTOR_TERMINAL_RECORD_INPUT (default false):
	// whether keystrokes are recorded as "i" events. Off by default because
	// the output already echoes what was typed, except passwords, which
	// would otherwise land in the file.
	RecordInput bool
	// Dir is PFCONNECTOR_TERMINAL_RECORDINGS_DIR or the default.
	Dir string
}

func terminalRecordingConfigFromEnv() terminalRecordingConfig {
	cfg := terminalRecordingConfig{
		Enabled:     true,
		RecordInput: false,
		Dir:         sharedutils.EnvOrDefault("PFCONNECTOR_TERMINAL_RECORDINGS_DIR", defaultTerminalRecordingsDir),
	}
	if v := strings.ToLower(strings.TrimSpace(os.Getenv("PFCONNECTOR_TERMINAL_RECORD"))); v != "" {
		if enabled, found := sharedutils.ISENABLED[v]; found {
			cfg.Enabled = enabled
		}
	}
	if v := strings.ToLower(strings.TrimSpace(os.Getenv("PFCONNECTOR_TERMINAL_RECORD_INPUT"))); v != "" {
		if enabled, found := sharedutils.ISENABLED[v]; found {
			cfg.RecordInput = enabled
		}
	}
	return cfg
}

// asciicastHeader is the first line of an asciicast v2 file.
type asciicastHeader struct {
	Version   int               `json:"version"`
	Width     int               `json:"width"`
	Height    int               `json:"height"`
	Timestamp int64             `json:"timestamp"`
	Title     string            `json:"title,omitempty"`
	Env       map[string]string `json:"env,omitempty"`
}

// asciicastRecorder appends asciicast v2 events to a file. Safe for
// concurrent use: gotty reads the pty from one goroutine and writes it
// (input, resize) from another.
type asciicastRecorder struct {
	mu          sync.Mutex
	file        *os.File
	w           *bufio.Writer
	start       time.Time
	path        string
	recordInput bool
	// pending holds the trailing bytes of an incomplete UTF-8 sequence split
	// across two pty reads, so every "o" event is a valid string.
	pending []byte
	closed  bool
	events  int
}

// recordingAdminUser restricts the admin username stored in the header.
var recordingAdminUser = regexp.MustCompile(`^[A-Za-z0-9@._+ -]{1,128}$`)

// newAsciicastRecorder creates <dir>/<UTC start>-<session>.cast and writes
// the header. The session is the activation uuid (or "unknown"); adminUser
// is the PacketFence admin who activated it (empty when unknown).
func newAsciicastRecorder(cfg terminalRecordingConfig, connectorID, session, adminUser string) (*asciicastRecorder, error) {
	if !recordingSessionName.MatchString(session) {
		session = "unknown"
	}
	if !recordingAdminUser.MatchString(adminUser) {
		adminUser = ""
	}
	if err := os.MkdirAll(cfg.Dir, 0o700); err != nil {
		return nil, fmt.Errorf("creating the terminal recordings directory %s: %w", cfg.Dir, err)
	}
	start := time.Now()
	base := start.UTC().Format("20060102T150405Z") + "-" + session
	path := filepath.Join(cfg.Dir, base+".cast")
	// Two connections of the same activation (gotty reconnect) within the
	// same second must not clobber each other.
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	for i := 1; err != nil && os.IsExist(err) && i < 100; i++ {
		path = filepath.Join(cfg.Dir, fmt.Sprintf("%s-%d.cast", base, i))
		file, err = os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	}
	if err != nil {
		return nil, fmt.Errorf("creating the terminal recording %s: %w", path, err)
	}

	r := &asciicastRecorder{
		file:        file,
		w:           bufio.NewWriter(file),
		start:       start,
		path:        path,
		recordInput: cfg.RecordInput,
	}
	header := asciicastHeader{
		Version:   2,
		Width:     defaultRecordingWidth,
		Height:    defaultRecordingHeight,
		Timestamp: start.Unix(),
		Title:     fmt.Sprintf("pfconnector-remote %s terminal session %s", connectorID, session),
		Env:       map[string]string{"TERM": "xterm-256color", "SHELL": "/bin/bash"},
	}
	if adminUser != "" {
		header.Title += " by " + adminUser
		header.Env["PF_ADMIN_USER"] = adminUser
	}
	if err := r.writeJSONLine(header); err != nil {
		file.Close()
		os.Remove(path)
		return nil, fmt.Errorf("writing the terminal recording header: %w", err)
	}
	return r, nil
}

// Path returns the recording file.
func (r *asciicastRecorder) Path() string {
	return r.path
}

func (r *asciicastRecorder) writeJSONLine(v interface{}) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	if _, err := r.w.Write(b); err != nil {
		return err
	}
	if err := r.w.WriteByte('\n'); err != nil {
		return err
	}
	// Flush per event: a crash or kill mid-session must not lose the
	// buffered tail of the transcript.
	return r.w.Flush()
}

// event appends [elapsed, code, data]; the caller holds r.mu.
func (r *asciicastRecorder) event(code, data string) {
	if r.closed || data == "" {
		return
	}
	elapsed := time.Since(r.start).Seconds()
	if err := r.writeJSONLine([]interface{}{elapsed, code, data}); err != nil {
		log.Printf("Terminal recording %s: write failed, stopping the recording: %v", r.path, err)
		r.closed = true
		r.file.Close()
		return
	}
	r.events++
}

// Output records bytes read from the pty (what the admin saw).
func (r *asciicastRecorder) Output(data []byte) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if len(r.pending) > 0 {
		data = append(append([]byte{}, r.pending...), data...)
		r.pending = nil
	}
	complete, tail := splitIncompleteUTF8(data)
	if len(tail) > 0 {
		r.pending = append([]byte{}, tail...)
	}
	// json.Marshal replaces any remaining invalid byte with U+FFFD.
	r.event("o", string(complete))
}

// Input records bytes written to the pty (keystrokes), when enabled.
func (r *asciicastRecorder) Input(data []byte) {
	if !r.recordInput {
		return
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	r.event("i", string(data))
}

// Resize records a terminal size change as an "r" event ("COLSxROWS").
func (r *asciicastRecorder) Resize(columns, rows int) {
	if columns <= 0 || rows <= 0 {
		return
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	r.event("r", fmt.Sprintf("%dx%d", columns, rows))
}

// Close flushes any pending partial rune and closes the file.
func (r *asciicastRecorder) Close() error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.closed {
		return nil
	}
	if len(r.pending) > 0 {
		r.event("o", string(r.pending))
		r.pending = nil
	}
	r.closed = true
	err := r.file.Close()
	log.Printf("Terminal recording %s closed after %s (%d events)", r.path, time.Since(r.start).Round(time.Second), r.events)
	return err
}

// splitIncompleteUTF8 splits data so that complete ends on a rune boundary
// and tail holds the (at most pendingUTF8Max) bytes of a multi-byte sequence
// still waiting for its continuation bytes. Invalid bytes that can never be
// completed stay in complete.
func splitIncompleteUTF8(data []byte) (complete, tail []byte) {
	n := len(data)
	if n == 0 {
		return data, nil
	}
	// Look back at most 3 bytes for a start byte whose sequence is cut.
	for back := 1; back <= pendingUTF8Max && back <= n; back++ {
		b := data[n-back]
		if b < utf8.RuneSelf {
			// ASCII: everything from here is complete.
			return data, nil
		}
		if b&0xC0 == 0x80 {
			// Continuation byte, keep looking for the start byte.
			continue
		}
		var need int
		switch {
		case b&0xE0 == 0xC0:
			need = 2
		case b&0xF0 == 0xE0:
			need = 3
		case b&0xF8 == 0xF0:
			need = 4
		default:
			// Not a valid start byte: nothing to wait for.
			return data, nil
		}
		if back < need {
			return data[:n-back], data[n-back:]
		}
		return data, nil
	}
	return data, nil
}
