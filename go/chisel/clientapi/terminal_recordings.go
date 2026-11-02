package clientapi

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/inverse-inc/go-utils/log"
)

// Access to the terminal session recordings (asciicast v2 files written by
// terminal_recording.go), for the PacketFence admin UI through the tunnel:
//
//	GET /api/v1/terminal-recordings          -> {"recordings": [...]} newest first
//	GET /api/v1/terminal-recordings/{name}   -> the .cast file (?download=1 for an attachment)
//
// Not under /api/v1/terminal: that prefix is reverse-proxied to gotty.

// recordingFileName is the only shape a recording file name may have
// (<UTC start>-<session>[-<n>].cast, see newAsciicastRecorder).
var recordingFileName = regexp.MustCompile(`^\d{8}T\d{6}Z-[A-Za-z0-9_.-]{1,64}?(-\d{1,2})?\.cast$`)

// recordingTailMax is how much of the end of a file is read to find its last
// event (the duration); a single output event is rarely near that size.
const recordingTailMax = 256 * 1024

// terminalRecording describes one recording in the listing.
type terminalRecording struct {
	Name string `json:"name"`
	// Session is the activation uuid the recording belongs to (from the
	// file name; several files share it when gotty reconnected).
	Session string `json:"session"`
	// AdminUser is the PacketFence admin who activated the session, when
	// the server passed it along (PF_ADMIN_USER in the header env).
	AdminUser string `json:"admin_user,omitempty"`
	// StartedAt is the header timestamp (RFC 3339, UTC).
	StartedAt string `json:"started_at"`
	// DurationSeconds is the time of the last event; 0 for a header-only file.
	DurationSeconds float64 `json:"duration_seconds"`
	Width           int     `json:"width"`
	Height          int     `json:"height"`
	Size            int64   `json:"size"`
	// InProgress reports a file still being written (modified in the last
	// few seconds while a terminal is active).
	InProgress bool `json:"in_progress"`
}

// mountTerminalRecordingRoutes registers the routes on r (a router already
// restricted to the tunnel / localhost).
func mountTerminalRecordingRoutes(r chi.Router, api *API) {
	r.Get("/terminal-recordings", listTerminalRecordings(api))
	r.Get("/terminal-recordings/{name}", serveTerminalRecording(api))
}

// listTerminalRecordings is GET /api/v1/terminal-recordings.
func listTerminalRecordings(api *API) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		recordings, err := scanTerminalRecordings(api.terminalRecording.Dir, api.terminalRunning())
		if err != nil {
			log.LoggerWContext(api.ctx).Error(fmt.Sprintf("Listing the terminal recordings: %v", err))
			writeMessage(w, http.StatusInternalServerError, "Unable to list the terminal recordings")
			return
		}
		writeJSON(w, http.StatusOK, map[string]interface{}{
			"enabled":    api.terminalRecording.Enabled,
			"recordings": recordings,
		})
	}
}

// scanTerminalRecordings reads the recordings directory and describes every
// .cast file in it, newest first. A missing directory is an empty list (no
// session was recorded yet).
func scanTerminalRecordings(dir string, terminalActive bool) ([]terminalRecording, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return []terminalRecording{}, nil
		}
		return nil, err
	}
	recordings := []terminalRecording{}
	for _, entry := range entries {
		if entry.IsDir() || !recordingFileName.MatchString(entry.Name()) {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			continue
		}
		rec := describeRecording(filepath.Join(dir, entry.Name()), info)
		rec.InProgress = terminalActive && time.Since(info.ModTime()) < 30*time.Second
		recordings = append(recordings, rec)
	}
	sort.Slice(recordings, func(i, j int) bool { return recordings[i].Name > recordings[j].Name })
	return recordings, nil
}

// describeRecording builds the listing entry of one file from its name, its
// header line and its last event.
func describeRecording(path string, info os.FileInfo) terminalRecording {
	name := info.Name()
	rec := terminalRecording{Name: name, Size: info.Size()}
	// <UTC start>-<session>[-<n>].cast
	base := strings.TrimSuffix(name, ".cast")
	if i := strings.IndexByte(base, '-'); i > 0 {
		session := base[i+1:]
		if m := regexp.MustCompile(`-\d{1,2}$`).FindStringIndex(session); m != nil && strings.Count(session, "-") > 4 {
			// a "-<n>" suffix after an uuid (which has 4 dashes)
			session = session[:m[0]]
		}
		rec.Session = session
	}

	f, err := os.Open(path)
	if err != nil {
		return rec
	}
	defer f.Close()

	// Header: first line.
	reader := bufio.NewReaderSize(f, 64*1024)
	line, err := reader.ReadBytes('\n')
	if err != nil && len(line) == 0 {
		return rec
	}
	var header asciicastHeader
	if json.Unmarshal(line, &header) == nil {
		rec.Width, rec.Height = header.Width, header.Height
		if header.Timestamp > 0 {
			rec.StartedAt = time.Unix(header.Timestamp, 0).UTC().Format(time.RFC3339)
		}
		rec.AdminUser = header.Env["PF_ADMIN_USER"]
	}
	if rec.StartedAt == "" {
		rec.StartedAt = info.ModTime().UTC().Format(time.RFC3339)
	}

	// Duration: the time of the last complete event line.
	rec.DurationSeconds = lastEventTime(f, info.Size(), int64(len(line)))
	return rec
}

// lastEventTime returns the elapsed time of the last complete event in the
// file (0 when there is none). headerLen is where the events start.
func lastEventTime(f *os.File, size, headerLen int64) float64 {
	if size <= headerLen {
		return 0
	}
	tailLen := size - headerLen
	if tailLen > recordingTailMax {
		tailLen = recordingTailMax
	}
	tail := make([]byte, tailLen)
	if _, err := f.ReadAt(tail, size-tailLen); err != nil && err != io.EOF {
		return 0
	}
	// Drop a trailing partial line (a write in progress), then walk the
	// complete lines backwards until one parses as an event.
	if end := bytes.LastIndexByte(tail, '\n'); end >= 0 {
		tail = tail[:end]
	} else {
		return 0
	}
	for len(tail) > 0 {
		start := bytes.LastIndexByte(tail, '\n') + 1
		lineBytes := tail[start:]
		var event []interface{}
		if json.Unmarshal(lineBytes, &event) == nil && len(event) == 3 {
			if t, ok := event[0].(float64); ok {
				return t
			}
		}
		if start == 0 {
			break
		}
		tail = tail[:start-1]
	}
	return 0
}

// serveTerminalRecording is GET /api/v1/terminal-recordings/{name}.
func serveTerminalRecording(api *API) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		name := chi.URLParam(r, "name")
		if !recordingFileName.MatchString(name) {
			writeMessage(w, http.StatusBadRequest, "Invalid recording name")
			return
		}
		path := filepath.Join(api.terminalRecording.Dir, name)
		f, err := os.Open(path)
		if err != nil {
			if os.IsNotExist(err) {
				writeMessage(w, http.StatusNotFound, "No such recording")
				return
			}
			log.LoggerWContext(api.ctx).Error(fmt.Sprintf("Opening the terminal recording %s: %v", path, err))
			writeMessage(w, http.StatusInternalServerError, "Unable to read the recording")
			return
		}
		defer f.Close()
		info, err := f.Stat()
		if err != nil || info.IsDir() {
			writeMessage(w, http.StatusNotFound, "No such recording")
			return
		}
		w.Header().Set("Content-Type", "application/x-asciicast; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		if r.URL.Query().Get("download") != "" {
			w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, name))
		}
		log.LoggerWContext(api.ctx).Info(fmt.Sprintf("Terminal recording %s served through the pfconnector-client API", name))
		// ServeContent handles Content-Length / ranges; the modtime is
		// omitted so a file still being written is never cached.
		http.ServeContent(w, r, name, time.Time{}, f)
	}
}
