package logtailer

// Time-window history mode for the log tailer.
//
// Where the tailing sessions in this plugin follow the *live* end of the
// active log files, the history endpoint reads the files at rest — the
// active file plus its .log.<N>.gz logrotate rotations — and returns the
// lines that fall inside a requested time window, paginated with a
// byte-offset cursor. Both modes share the line-format contract in
// logmeta.go, so the parsing exists exactly once.
//
// Safety properties relied upon by the admin API:
//   - filenames are validated against the syslog allow-list before any
//     path is built (no traversal out of the log directory)
//   - filters are RE2 (regexp.Compile): no catastrophic backtracking, a
//     hostile pattern cannot hang the worker
//   - the scan is bounded by a wall-clock budget and a decompressed-byte
//     ceiling in addition to the event cap; when a bound is hit the
//     response carries truncated=true and a cursor that resumes exactly
//     where the scan stopped (cursors advance over non-matching regions
//     too, so a filter with no matches still makes progress)

import (
	"bufio"
	"compress/gzip"
	"fmt"
	"hash/fnv"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

const (
	historyMaxEvents       = 500
	historyScanBudget      = 5 * time.Second
	historyMaxScanBytes    = 256 << 20 // decompressed
	historyDefaultWindow   = 24 * time.Hour
	historyMaxFilterLength = 256
	historySigBytes        = 256
	// A line stamped further than this beyond the window end is treated as
	// a clock anomaly (corrupt line, badly skewed clock) and skipped, so a
	// single bogus far-future timestamp cannot hide everything after it.
	historyAnomalousSkewMs = int64(24 * time.Hour / time.Millisecond)
)

// Package var (not const) so tests can point the scanner at a fixture dir.
var historyLogDir = "/usr/local/pf/logs"

type historyCursor struct {
	// Rotation index of the source this cursor points into (0 = active file).
	Source int `json:"source"`
	// Uncompressed byte offset of the next unread line within that source.
	Offset int64 `json:"offset"`
	// Identity of the source content (hash of its first SigLen bytes) so a
	// logrotate rename between two polls is detected: the same content is
	// found again under its new rotation index and the byte offset stays
	// valid because rotation never rewrites the data. SigLen pins the
	// hashed prefix length — log files are append-only, so the hash over a
	// FIXED length is stable even while the file keeps growing.
	Sig    string `json:"sig"`
	SigLen int    `json:"sig_len"`
	// Timestamp (unix ms) of the last line scanned. Only used as a resume
	// fallback when the source the cursor points to has disappeared
	// (e.g. rotation pruned by retention): lines <= this are skipped.
	TsMs int64 `json:"ts_ms"`
}

type historyEventMeta struct {
	Timestamp        string `json:"timestamp"`
	Hostname         string `json:"hostname"`
	Process          string `json:"process"`
	SyslogName       string `json:"syslog_name"`
	LogLevel         string `json:"log_level"`
	Filename         string `json:"filename"`
	LogWithoutPrefix string `json:"log_without_prefix"`
}

type historyEvent struct {
	Data struct {
		Raw  string           `json:"raw"`
		Meta historyEventMeta `json:"meta"`
	} `json:"data"`
}

type historyRequest struct {
	Files          []string                  `json:"files"`
	Filter         string                    `json:"filter"`
	FilterIsRegexp bool                      `json:"filter_is_regexp"`
	Start          string                    `json:"start"`
	End            string                    `json:"end"`
	Cursor         map[string]*historyCursor `json:"cursor"`
}

type historyResponse struct {
	Events    []historyEvent            `json:"events"`
	Cursor    map[string]*historyCursor `json:"cursor"`
	Truncated bool                      `json:"truncated"`
}

// allowedHistoryFiles maps the syslog_files pfconfig resource (full paths,
// including non-log-dir entries like /var/log/syslog) to the basename
// contract the admin UI uses. Only files under the log directory are
// exposed: the history scanner enumerates rotations next to the active
// file, which only makes sense inside the PacketFence log dir.
func allowedHistoryFiles(elements []syslogFileElement) map[string]string {
	prefix := historyLogDir + "/"
	allowed := map[string]string{}
	for _, e := range elements {
		if strings.HasPrefix(e.Name, prefix) {
			base := strings.TrimPrefix(e.Name, prefix)
			if base != "" && !strings.ContainsAny(base, "/\\") {
				allowed[base] = e.Description
			}
		}
	}
	return allowed
}

type syslogFileElement struct {
	Name        string
	Description string
}

func syslogFileElements(c *gin.Context) []syslogFileElement {
	pfconfigdriver.FetchDecodeSocketCache(c, &logs)
	elements := make([]syslogFileElement, 0, len(logs.Element))
	for _, l := range logs.Element {
		elements = append(elements, syslogFileElement{Name: l.Name, Description: l.Description})
	}
	return elements
}

func (h *LogTailerHandler) optionsHistory(c *gin.Context) {
	allowed := allowedHistoryFiles(syslogFileElements(c))

	names := make([]string, 0, len(allowed))
	for name := range allowed {
		names = append(names, name)
	}
	sort.Slice(names, func(i, j int) bool {
		return strings.ToLower(allowed[names[i]]) < strings.ToLower(allowed[names[j]])
	})
	files := []gin.H{}
	for _, name := range names {
		files = append(files, gin.H{"text": allowed[name], "value": name})
	}

	c.JSON(http.StatusOK, gin.H{
		"meta": gin.H{
			"filter": gin.H{
				"type": "string", "required": false, "default": nil, "placeholder": nil,
			},
			"filter_is_regexp": gin.H{
				"type": "string", "required": false, "default": nil, "placeholder": false,
			},
			"files": gin.H{
				"type": "array", "required": true, "placeholder": nil, "default": nil,
				"item": gin.H{
					"type": "string", "required": true, "placeholder": nil, "default": nil,
					"allowed": files,
				},
			},
			"start": gin.H{
				"type": "string", "required": false, "default": nil,
				"placeholder": "ISO-8601 timestamp (inclusive lower bound)",
			},
			"end": gin.H{
				"type": "string", "required": false, "default": nil,
				"placeholder": "ISO-8601 timestamp (exclusive upper bound)",
			},
		},
	})
}

func (h *LogTailerHandler) queryHistory(c *gin.Context) {
	req := historyRequest{}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Unable to parse JSON payload"})
		return
	}

	allowed := allowedHistoryFiles(syslogFileElements(c))
	resp, errMsg := runHistoryQuery(&req, allowed)
	if errMsg != "" {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"message": errMsg, "errors": []string{}, "status": http.StatusUnprocessableEntity})
		return
	}
	c.JSON(http.StatusOK, resp)
}

// runHistoryQuery validates the request and runs the bounded scan. It is
// deliberately free of gin/pfconfig so the unit tests can drive it with a
// fixture directory. A non-empty second return value is a 422 message.
func runHistoryQuery(req *historyRequest, allowed map[string]string) (*historyResponse, string) {
	if len(req.Files) == 0 {
		return nil, "No files were specified"
	}
	bad := []string{}
	for _, f := range req.Files {
		if _, ok := allowed[f]; !ok {
			bad = append(bad, f)
		}
	}
	if len(bad) > 0 {
		return nil, "Unknown file(s): " + strings.Join(bad, ",")
	}

	startMs, err := historyParseISO(req.Start)
	if err != nil {
		return nil, fmt.Sprintf("Invalid start timestamp: %s", err)
	}
	endMs, err := historyParseISO(req.End)
	if err != nil {
		return nil, fmt.Sprintf("Invalid end timestamp: %s", err)
	}

	if len(req.Filter) > historyMaxFilterLength {
		return nil, fmt.Sprintf("Filter is too long (maximum %d characters)", historyMaxFilterLength)
	}
	var filterRe *regexp.Regexp
	if req.Filter != "" {
		// RE2 — immune to catastrophic backtracking by construction.
		// Case-insensitive to match the live-tail filter semantics.
		pattern := `(?i)` + req.Filter
		if !req.FilterIsRegexp {
			pattern = `(?i)` + regexp.QuoteMeta(req.Filter)
		}
		filterRe, err = regexp.Compile(pattern)
		if err != nil {
			return nil, fmt.Sprintf("Invalid regex filter: %s", err)
		}
	}

	nowMs := time.Now().UnixMilli()
	// Default to the last 24h: without any bound the scan would walk every
	// rotation back to retention on the very first poll.
	if startMs == 0 && len(req.Cursor) == 0 {
		startMs = nowMs - historyDefaultWindow.Milliseconds()
	}
	if endMs == 0 {
		endMs = nowMs + time.Minute.Milliseconds()
	}

	scan := &historyScan{
		startMs:  startMs,
		endMs:    endMs,
		filter:   filterRe,
		deadline: time.Now().Add(historyScanBudget),
	}

	resp := &historyResponse{
		Events: []historyEvent{},
		Cursor: map[string]*historyCursor{},
	}
	for name, cur := range req.Cursor {
		resp.Cursor[name] = cur
	}

	for _, name := range req.Files {
		exhausted := scan.scanFile(name, req.Cursor[name], resp)
		if !exhausted {
			resp.Truncated = true
			break
		}
	}
	return resp, ""
}

type historyScan struct {
	startMs      int64
	endMs        int64
	filter       *regexp.Regexp
	deadline     time.Time
	bytesScanned int64
	lineCount    int64
}

type historySource struct {
	path    string
	gz      bool
	idx     int
	mtimeMs int64
}

// over reports whether one of the global scan budgets is exhausted. The
// wall clock is only sampled every 256 lines to keep the per-line cost low.
func (s *historyScan) over(eventCount int) bool {
	if eventCount >= historyMaxEvents || s.bytesScanned >= historyMaxScanBytes {
		return true
	}
	s.lineCount++
	return s.lineCount%256 == 0 && time.Now().After(s.deadline)
}

// scanFile scans one logical file (active + rotations) and appends matching
// events. It returns true when the file was fully scanned within budget,
// false when a budget bound stopped it early (cursor left mid-file).
func (s *historyScan) scanFile(name string, cur *historyCursor, resp *historyResponse) bool {
	floorMs := s.startMs
	if cur != nil && cur.TsMs > floorMs {
		floorMs = cur.TsMs
	}
	sources := enumerateHistorySources(name, floorMs, s.endMs)
	if len(sources) == 0 {
		return true
	}

	startIdx, skipOffset, tsFloor := locateHistoryResume(sources, cur)

	// Seed the continuation context from the cursor: a multi-line event cut
	// by the previous page boundary must still be attributed and delivered.
	lastTsMs := int64(0)
	if cur != nil {
		lastTsMs = cur.TsMs
	}
	var lastMeta historyEventMeta
	haveLastMeta := false

	for i := startIdx; i < len(sources); i++ {
		src := sources[i]
		reader, err := openHistorySource(src)
		if err != nil {
			continue
		}

		offset := int64(0)
		if i == startIdx && skipOffset > 0 {
			if !discardHistoryBytes(reader, src, skipOffset) {
				reader.Close()
				continue
			}
			offset = skipOffset
		}

		cursorAt := func() *historyCursor {
			sig, sigLen := historySourceSig(src.path)
			return &historyCursor{Source: src.idx, Offset: offset, Sig: sig, SigLen: sigLen, TsMs: lastTsMs}
		}

		br := bufio.NewReaderSize(reader, 64*1024)
		for {
			line, err := br.ReadString('\n')
			if err != nil {
				// A final line without a newline is a partial write on the
				// active file: leave it for the next poll, the cursor still
				// points at its first byte.
				break
			}
			lineLen := int64(len(line))
			line = strings.TrimRight(line, "\n")
			s.bytesScanned += lineLen

			if s.over(len(resp.Events)) {
				resp.Cursor[name] = cursorAt()
				reader.Close()
				return false
			}
			if line == "" {
				offset += lineLen
				continue
			}

			meta, rawTs, headerOK := metaEngine.ExtractMetaISO(line)
			tsMs := int64(0)
			if headerOK {
				tsMs = meta.Timestamp.UnixMilli()
			} else if lastTsMs != 0 {
				// Multi-line continuation (stack trace, …): attribute it to
				// the previous event so it stays visible in the result.
				tsMs = lastTsMs
			} else {
				offset += lineLen
				continue
			}

			if tsMs >= s.endMs {
				if tsMs-s.endMs > historyAnomalousSkewMs {
					// Clock anomaly — skip the line instead of stopping, so
					// it cannot hide every later (sane) line of the file.
					offset += lineLen
					continue
				}
				// Lines are appended chronologically; everything after this
				// point in this source — and in every newer source — is out
				// of the window. Leave the cursor *before* this line.
				resp.Cursor[name] = cursorAt()
				reader.Close()
				return true
			}
			offset += lineLen
			if headerOK {
				lastTsMs = tsMs
				lastMeta = historyEventMeta{
					Timestamp:        rawTs,
					Hostname:         meta.Hostname,
					Process:          meta.SyslogName,
					SyslogName:       meta.SyslogName,
					LogLevel:         meta.LogLevel,
					Filename:         name,
					LogWithoutPrefix: meta.LogWithoutPrefix,
				}
				haveLastMeta = true
			}
			if tsMs < s.startMs || (tsFloor > 0 && tsMs <= tsFloor) {
				continue
			}
			if s.filter != nil && !s.filter.MatchString(line) {
				continue
			}

			ev := historyEvent{}
			ev.Data.Raw = line
			if haveLastMeta {
				ev.Data.Meta = lastMeta
				if !headerOK {
					ev.Data.Meta.LogWithoutPrefix = line
				}
			} else {
				ev.Data.Meta = historyEventMeta{Filename: name, LogWithoutPrefix: line}
			}
			resp.Events = append(resp.Events, ev)
		}
		resp.Cursor[name] = cursorAt()
		reader.Close()
	}
	return true
}

// locateHistoryResume finds the source a cursor points into. The source is
// identified by content signature, not by rotation index alone: logrotate
// renames file.log to file.log.1.gz between polls, so the same content can
// reappear under a different index while the (uncompressed) byte offset
// stays valid. When the signature is gone (retention pruned the rotation),
// fall back to skipping lines up to the cursor timestamp.
func locateHistoryResume(sources []historySource, cur *historyCursor) (startIdx int, skipOffset int64, tsFloor int64) {
	if cur == nil {
		return 0, 0, 0
	}
	// A signature over zero bytes carries no identity: an empty active file
	// looks like every other empty file, so matching it would silently skip
	// rotations written in between. Fall back to the timestamp floor.
	// SigLen is client JSON: values above what the server ever emits would
	// turn historySourceSigN into an unbounded allocation/decompression
	// outside the scan budgets, so clamp them to the same fallback.
	if cur.Sig == "" || cur.SigLen <= 0 || cur.SigLen > historySigBytes {
		return 0, 0, cur.TsMs
	}
	match := -1
	for i, src := range sources {
		// Compare over exactly the prefix length the cursor hashed: the
		// file may have grown since (append-only), the first SigLen bytes
		// have not changed.
		if historySourceSigN(src.path, cur.SigLen) == cur.Sig {
			match = i
			if src.idx == cur.Source {
				break
			}
		}
	}
	if match >= 0 {
		return match, cur.Offset, 0
	}
	return 0, 0, cur.TsMs
}

func enumerateHistorySources(name string, floorMs, endMs int64) []historySource {
	sources := []historySource{}

	entries, err := os.ReadDir(historyLogDir)
	if err != nil {
		return sources
	}
	rotationRe := regexp.MustCompile(`^` + regexp.QuoteMeta(name) + `\.(\d+)\.gz$`)
	for _, entry := range entries {
		m := rotationRe.FindStringSubmatch(entry.Name())
		if m == nil {
			continue
		}
		idx := 0
		fmt.Sscanf(m[1], "%d", &idx)
		sources = append(sources, historySource{path: filepath.Join(historyLogDir, entry.Name()), gz: true, idx: idx})
	}
	// Higher index = older; read oldest first, active file last.
	sort.Slice(sources, func(i, j int) bool { return sources[i].idx > sources[j].idx })

	active := filepath.Join(historyLogDir, name)
	if st, err := os.Stat(active); err == nil && st.Mode().IsRegular() {
		sources = append(sources, historySource{path: active, gz: false, idx: 0})
	}

	// Daily logrotate: a rotation's mtime ≈ right edge of its content
	// window, (mtime - 1d) ≈ left. Skip rotations that cannot intersect
	// the requested window so they are never even decompressed.
	const dayMs = int64(86_400_000)
	kept := sources[:0]
	for _, src := range sources {
		st, err := os.Stat(src.path)
		if err != nil {
			continue
		}
		src.mtimeMs = st.ModTime().UnixMilli()
		if src.gz {
			if floorMs > 0 && src.mtimeMs < floorMs {
				continue
			}
			if endMs > 0 && src.mtimeMs-dayMs > endMs {
				continue
			}
		}
		kept = append(kept, src)
	}
	return kept
}

func openHistorySource(src historySource) (io.ReadCloser, error) {
	f, err := os.Open(src.path)
	if err != nil {
		return nil, err
	}
	if !src.gz {
		return f, nil
	}
	gz, err := gzip.NewReader(f)
	if err != nil {
		f.Close()
		return nil, err
	}
	return &gzipSourceReader{gz: gz, f: f}, nil
}

type gzipSourceReader struct {
	gz *gzip.Reader
	f  *os.File
}

func (r *gzipSourceReader) Read(p []byte) (int, error) { return r.gz.Read(p) }
func (r *gzipSourceReader) Close() error {
	r.gz.Close()
	return r.f.Close()
}

// discardHistoryBytes advances a source reader to a resume offset. Plain
// files seek; gzip streams are not seekable, so the prefix is decompressed
// and discarded (cheap relative to scanning it, and rotations that cannot
// contain the window were already filtered out by mtime).
func discardHistoryBytes(reader io.ReadCloser, src historySource, offset int64) bool {
	if !src.gz {
		if f, ok := reader.(*os.File); ok {
			_, err := f.Seek(offset, io.SeekStart)
			return err == nil
		}
	}
	_, err := io.CopyN(io.Discard, reader, offset)
	return err == nil
}

// historySourceSig hashes the available content prefix (up to
// historySigBytes) and returns the hash with the number of bytes it covers.
// An empty file yields ("", 0) — no identity.
func historySourceSig(path string) (string, int) {
	return historySourceSigRead(path, historySigBytes, false)
}

// historySourceSigN hashes exactly n prefix bytes for cursor matching; a
// source shorter than n cannot be the file the cursor was taken on (content
// is append-only) and yields "".
func historySourceSigN(path string, n int) string {
	sig, _ := historySourceSigRead(path, n, true)
	return sig
}

func historySourceSigRead(path string, n int, exact bool) (string, int) {
	f, err := os.Open(path)
	if err != nil {
		return "", 0
	}
	defer f.Close()

	var reader io.Reader = f
	if strings.HasSuffix(path, ".gz") {
		gz, err := gzip.NewReader(f)
		if err != nil {
			return "", 0
		}
		defer gz.Close()
		reader = gz
	}
	buf := make([]byte, n)
	got, _ := io.ReadFull(reader, buf)
	if got == 0 || (exact && got < n) {
		return "", 0
	}
	h := fnv.New64a()
	h.Write(buf[:got])
	return fmt.Sprintf("%x", h.Sum64()), got
}

// historyParseISO returns unix milliseconds for an ISO-8601/RFC3339
// timestamp, 0 for an empty input, or an error.
func historyParseISO(s string) (int64, error) {
	if s == "" {
		return 0, nil
	}
	t, err := time.Parse(time.RFC3339Nano, s)
	if err != nil {
		return 0, err
	}
	return t.UnixMilli(), nil
}
