package logtailer

import (
	"compress/gzip"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

var testAllowed = map[string]string{
	"packetfence.log": "PacketFence general log",
	"pfdhcp.log":      "DHCP log",
}

func writeHistoryFixture(t *testing.T, name string, lines []string) {
	t.Helper()
	err := os.WriteFile(filepath.Join(historyLogDir, name), []byte(strings.Join(lines, "\n")+"\n"), 0644)
	if err != nil {
		t.Fatal(err)
	}
}

func writeHistoryGzFixture(t *testing.T, name string, lines []string) {
	t.Helper()
	f, err := os.Create(filepath.Join(historyLogDir, name))
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	gz := gzip.NewWriter(f)
	if _, err := gz.Write([]byte(strings.Join(lines, "\n") + "\n")); err != nil {
		t.Fatal(err)
	}
	if err := gz.Close(); err != nil {
		t.Fatal(err)
	}
}

func useHistoryFixtureDir(t *testing.T) {
	t.Helper()
	orig := historyLogDir
	historyLogDir = t.TempDir()
	t.Cleanup(func() { historyLogDir = orig })
}

func isoLine(ts, msg string) string {
	return fmt.Sprintf("%s packetfence1 pfperl-api-docker-wrapper[1234]: pfperl-api(99) INFO: %s", ts, msg)
}

func TestHistoryAllowList(t *testing.T) {
	useHistoryFixtureDir(t)

	for _, files := range [][]string{
		{},
		{"../conf/pf.conf"},
		{"../../etc/passwd"},
		{"packetfence.log.1.gz"},
		{"/var/log/syslog"},
		{"packetfence.log", "unknown.log"},
	} {
		req := &historyRequest{Files: files}
		_, errMsg := runHistoryQuery(req, testAllowed)
		if errMsg == "" {
			t.Errorf("files %v: expected a validation error, got none", files)
		}
	}
}

func TestHistoryAllowListDerivation(t *testing.T) {
	orig := historyLogDir
	historyLogDir = "/usr/local/pf/logs"
	defer func() { historyLogDir = orig }()

	allowed := allowedHistoryFiles([]syslogFileElement{
		{Name: "/usr/local/pf/logs/packetfence.log", Description: "PacketFence general log"},
		{Name: "/var/log/syslog", Description: "Global syslog"},
		{Name: "/usr/local/pf/logs/../../../etc/passwd", Description: "evil"},
	})
	if _, ok := allowed["packetfence.log"]; !ok {
		t.Error("expected packetfence.log in the allow-list")
	}
	if len(allowed) != 1 {
		t.Errorf("expected only log-dir basenames in the allow-list, got %v", allowed)
	}
}

func TestHistoryInvalidFilter(t *testing.T) {
	useHistoryFixtureDir(t)
	writeHistoryFixture(t, "packetfence.log", []string{isoLine("2026-06-11T10:00:00.000000+02:00", "x")})

	req := &historyRequest{Files: []string{"packetfence.log"}, Filter: "([invalid", FilterIsRegexp: true}
	_, errMsg := runHistoryQuery(req, testAllowed)
	if errMsg == "" {
		t.Error("expected invalid regex to be rejected")
	}

	req = &historyRequest{Files: []string{"packetfence.log"}, Filter: strings.Repeat("a", historyMaxFilterLength+1)}
	_, errMsg = runHistoryQuery(req, testAllowed)
	if errMsg == "" {
		t.Error("expected over-long filter to be rejected")
	}

	// The classic catastrophic-backtracking pattern is harmless under RE2:
	// it must compile and the scan must return promptly.
	long := strings.Repeat("a", 4096)
	writeHistoryFixture(t, "packetfence.log", []string{isoLine("2026-06-11T10:00:00.000000+02:00", long+"!")})
	req = &historyRequest{
		Files: []string{"packetfence.log"}, Filter: "(a+)+$", FilterIsRegexp: true,
		Start: "2026-06-11T00:00:00+02:00", End: "2026-06-12T00:00:00+02:00",
	}
	begin := time.Now()
	resp, errMsg := runHistoryQuery(req, testAllowed)
	if errMsg != "" {
		t.Fatalf("unexpected error: %s", errMsg)
	}
	if elapsed := time.Since(begin); elapsed > historyScanBudget+2*time.Second {
		t.Errorf("evil pattern took %s, expected a prompt return", elapsed)
	}
	if len(resp.Events) != 0 {
		t.Errorf("expected 0 events, got %d", len(resp.Events))
	}
}

func TestHistoryWindowAndMeta(t *testing.T) {
	useHistoryFixtureDir(t)
	writeHistoryFixture(t, "packetfence.log", []string{
		isoLine("2026-06-11T09:00:00.000000+02:00", "before window"),
		isoLine("2026-06-11T10:00:00.100000+02:00", "in window one"),
		"continuation line without a header",
		isoLine("2026-06-11T10:00:01.200000+02:00", "in window two"),
		isoLine("2026-06-11T11:00:00.000000+02:00", "after window"),
	})

	req := &historyRequest{
		Files: []string{"packetfence.log"},
		Start: "2026-06-11T10:00:00+02:00",
		End:   "2026-06-11T10:30:00+02:00",
	}
	resp, errMsg := runHistoryQuery(req, testAllowed)
	if errMsg != "" {
		t.Fatalf("unexpected error: %s", errMsg)
	}
	if len(resp.Events) != 3 {
		t.Fatalf("expected 3 events (2 headers + 1 continuation), got %d", len(resp.Events))
	}

	first := resp.Events[0].Data.Meta
	if first.Timestamp != "2026-06-11T10:00:00.100000+02:00" {
		t.Errorf("unexpected timestamp: %s", first.Timestamp)
	}
	if first.Hostname != "packetfence1" || first.SyslogName != "pfperl-api-docker-wrapper" {
		t.Errorf("unexpected hostname/syslog_name: %+v", first)
	}
	if first.LogLevel != "info" {
		t.Errorf("expected log_level info, got %q", first.LogLevel)
	}
	if first.Filename != "packetfence.log" {
		t.Errorf("expected filename packetfence.log, got %q", first.Filename)
	}

	cont := resp.Events[1].Data.Meta
	if cont.LogWithoutPrefix != "continuation line without a header" {
		t.Errorf("continuation not attributed: %+v", cont)
	}
	if cont.Timestamp != first.Timestamp {
		t.Errorf("continuation should inherit the previous timestamp")
	}

	if resp.Truncated {
		t.Error("small scan must not be truncated")
	}
}

func TestHistorySubstringAndRegexFilter(t *testing.T) {
	useHistoryFixtureDir(t)
	writeHistoryFixture(t, "packetfence.log", []string{
		isoLine("2026-06-11T10:00:00.000000+02:00", "alpha event"),
		isoLine("2026-06-11T10:00:01.000000+02:00", "BETA event"),
		isoLine("2026-06-11T10:00:02.000000+02:00", "gamma event"),
	})
	window := &historyRequest{
		Files: []string{"packetfence.log"},
		Start: "2026-06-11T00:00:00+02:00", End: "2026-06-12T00:00:00+02:00",
	}

	req := *window
	req.Filter = "beta"
	resp, _ := runHistoryQuery(&req, testAllowed)
	if len(resp.Events) != 1 || !strings.Contains(resp.Events[0].Data.Raw, "BETA") {
		t.Errorf("case-insensitive substring filter failed: %d events", len(resp.Events))
	}

	req = *window
	req.Filter, req.FilterIsRegexp = "^.*(alpha|gamma)", true
	resp, _ = runHistoryQuery(&req, testAllowed)
	if len(resp.Events) != 2 {
		t.Errorf("regex filter expected 2 events, got %d", len(resp.Events))
	}
}

func TestHistoryCursorPagination(t *testing.T) {
	useHistoryFixtureDir(t)

	// 1200 lines across only two distinct millisecond timestamps — the exact
	// shape that loses lines with a timestamp-based cursor. The byte-offset
	// cursor must deliver every line exactly once across pages.
	lines := []string{}
	for i := 0; i < 1200; i++ {
		ts := "2026-06-11T10:00:00.000000+02:00"
		if i >= 600 {
			ts = "2026-06-11T10:00:00.001000+02:00"
		}
		lines = append(lines, isoLine(ts, fmt.Sprintf("event %04d", i)))
	}
	writeHistoryFixture(t, "packetfence.log", lines)

	seen := map[string]int{}
	cursor := map[string]*historyCursor{}
	total := 0
	for page := 0; page < 10; page++ {
		req := &historyRequest{
			Files:  []string{"packetfence.log"},
			Start:  "2026-06-11T00:00:00+02:00",
			End:    "2026-06-12T00:00:00+02:00",
			Cursor: cursor,
		}
		resp, errMsg := runHistoryQuery(req, testAllowed)
		if errMsg != "" {
			t.Fatalf("page %d: %s", page, errMsg)
		}
		for _, ev := range resp.Events {
			seen[ev.Data.Raw]++
			total++
		}
		cursor = resp.Cursor
		if len(resp.Events) == 0 && !resp.Truncated {
			break
		}
	}

	if total != 1200 {
		t.Fatalf("expected 1200 events total across pages, got %d", total)
	}
	for raw, count := range seen {
		if count != 1 {
			t.Fatalf("line delivered %d times: %s", count, raw)
		}
	}
}

func TestHistoryTruncatedFlag(t *testing.T) {
	useHistoryFixtureDir(t)
	lines := []string{}
	for i := 0; i < historyMaxEvents+50; i++ {
		lines = append(lines, isoLine(fmt.Sprintf("2026-06-11T10:00:%02d.%06d+02:00", i/1000, (i%1000)*1000), fmt.Sprintf("event %d", i)))
	}
	writeHistoryFixture(t, "packetfence.log", lines)

	req := &historyRequest{
		Files: []string{"packetfence.log"},
		Start: "2026-06-11T00:00:00+02:00", End: "2026-06-12T00:00:00+02:00",
	}
	resp, errMsg := runHistoryQuery(req, testAllowed)
	if errMsg != "" {
		t.Fatal(errMsg)
	}
	if !resp.Truncated {
		t.Error("expected truncated=true when the event cap stops the scan")
	}
	if len(resp.Events) != historyMaxEvents {
		t.Errorf("expected %d events on the first page, got %d", historyMaxEvents, len(resp.Events))
	}

	req.Cursor = resp.Cursor
	resp2, errMsg := runHistoryQuery(req, testAllowed)
	if errMsg != "" {
		t.Fatal(errMsg)
	}
	if resp2.Truncated {
		t.Error("second page should not be truncated")
	}
	if len(resp.Events)+len(resp2.Events) != historyMaxEvents+50 {
		t.Errorf("pages should add up: %d + %d", len(resp.Events), len(resp2.Events))
	}
}

func TestHistoryGzRotations(t *testing.T) {
	useHistoryFixtureDir(t)
	writeHistoryGzFixture(t, "packetfence.log.2.gz", []string{
		isoLine("2026-06-11T08:00:00.000000+02:00", "oldest"),
	})
	writeHistoryGzFixture(t, "packetfence.log.1.gz", []string{
		isoLine("2026-06-11T09:00:00.000000+02:00", "older"),
	})
	writeHistoryFixture(t, "packetfence.log", []string{
		isoLine("2026-06-11T10:00:00.000000+02:00", "newest"),
	})

	req := &historyRequest{
		Files: []string{"packetfence.log"},
		Start: "2026-06-11T00:00:00+02:00", End: "2026-06-12T00:00:00+02:00",
	}
	resp, errMsg := runHistoryQuery(req, testAllowed)
	if errMsg != "" {
		t.Fatal(errMsg)
	}
	if len(resp.Events) != 3 {
		t.Fatalf("expected 3 events across rotations, got %d", len(resp.Events))
	}
	for i, want := range []string{"oldest", "older", "newest"} {
		if !strings.HasSuffix(resp.Events[i].Data.Meta.LogWithoutPrefix, want) {
			t.Errorf("rotations not read oldest-first: event %d = %q, want suffix %q",
				i, resp.Events[i].Data.Meta.LogWithoutPrefix, want)
		}
	}
}

func TestHistoryRotationBetweenPolls(t *testing.T) {
	useHistoryFixtureDir(t)

	pageOne := []string{
		isoLine("2026-06-11T10:00:00.000000+02:00", "first"),
		isoLine("2026-06-11T10:00:01.000000+02:00", "second"),
	}
	writeHistoryFixture(t, "packetfence.log", pageOne)

	req := &historyRequest{
		Files: []string{"packetfence.log"},
		Start: "2026-06-11T00:00:00+02:00", End: "2026-06-12T00:00:00+02:00",
	}
	resp, errMsg := runHistoryQuery(req, testAllowed)
	if errMsg != "" {
		t.Fatal(errMsg)
	}
	if len(resp.Events) != 2 {
		t.Fatalf("expected 2 events on the first poll, got %d", len(resp.Events))
	}

	// Simulate logrotate between polls: the active file is compressed to
	// .1.gz and a fresh active file starts. The cursor pointed at the end
	// of the old active file; the signature must find that content again
	// under its new name so nothing is replayed and nothing is lost.
	writeHistoryGzFixture(t, "packetfence.log.1.gz", pageOne)
	writeHistoryFixture(t, "packetfence.log", []string{
		isoLine("2026-06-11T10:00:02.000000+02:00", "third"),
	})

	req.Cursor = resp.Cursor
	resp2, errMsg := runHistoryQuery(req, testAllowed)
	if errMsg != "" {
		t.Fatal(errMsg)
	}
	if len(resp2.Events) != 1 || !strings.Contains(resp2.Events[0].Data.Raw, "third") {
		raws := []string{}
		for _, ev := range resp2.Events {
			raws = append(raws, ev.Data.Raw)
		}
		t.Fatalf("expected exactly the new line after rotation, got %v", raws)
	}
}

func TestExtractMetaISO(t *testing.T) {
	meta, rawTs, ok := metaEngine.ExtractMetaISO("2026-06-11T00:00:18.164560+02:00 packetfence1 pfperl-api-docker-wrapper[289102]: pfperl-api(11740) INFO: [mac:[undef]] message here")
	if !ok {
		t.Fatal("expected ISO line to parse")
	}
	if rawTs != "2026-06-11T00:00:18.164560+02:00" {
		t.Errorf("rawTs: %s", rawTs)
	}
	if meta.Hostname != "packetfence1" {
		t.Errorf("hostname: %s", meta.Hostname)
	}
	if meta.SyslogName != "pfperl-api-docker-wrapper" {
		t.Errorf("syslog_name: %s", meta.SyslogName)
	}
	if meta.LogLevel != "info" {
		t.Errorf("log_level: %s", meta.LogLevel)
	}
	if meta.Timestamp.UnixMilli() == 0 {
		t.Error("timestamp not parsed")
	}

	if _, _, ok := metaEngine.ExtractMetaISO("  at Some::Module line 42"); ok {
		t.Error("continuation line must not parse as a header")
	}

	// lvl= form used by the golang daemons
	meta, _, ok = metaEngine.ExtractMetaISO("2026-06-11T00:00:18.164560+02:00 packetfence1 pfdhcp[1]: t=2026-06-11 lvl=eror msg=x")
	if !ok || meta.LogLevel != "error" {
		t.Errorf("lvl= extraction failed: ok=%v level=%q", ok, meta.LogLevel)
	}

	// ExtractMeta (live-tail path) must also handle ISO lines now
	lm := metaEngine.ExtractMeta("2026-06-11T00:00:18.164560+02:00 packetfence1 pfperl-api-docker-wrapper[289102]: pfperl-api(11740) WARN: something")
	if lm.Hostname != "packetfence1" || lm.LogLevel != "warn" {
		t.Errorf("ExtractMeta ISO path failed: %+v", lm)
	}
}

// Regression: a cursor taken while the active file is empty must never
// sig-match another empty file — otherwise rotations written in between
// are skipped entirely.
func TestHistoryEmptySigNeverMatches(t *testing.T) {
	useHistoryFixtureDir(t)
	writeHistoryGzFixture(t, "packetfence.log.1.gz", []string{isoLine("2026-06-11T08:00:00.000000+02:00", "B")})
	if err := os.WriteFile(filepath.Join(historyLogDir, "packetfence.log"), []byte(""), 0644); err != nil {
		t.Fatal(err)
	}

	req := &historyRequest{Files: []string{"packetfence.log"},
		Start: "2026-06-11T00:00:00+02:00", End: "2026-06-12T00:00:00+02:00"}
	resp, errMsg := runHistoryQuery(req, testAllowed)
	if errMsg != "" {
		t.Fatal(errMsg)
	}
	if len(resp.Events) != 1 {
		t.Fatalf("poll1: want 1 event, got %d", len(resp.Events))
	}

	// Line C is written to the active file and rotated away before the next
	// poll; the active file is empty again.
	writeHistoryGzFixture(t, "packetfence.log.2.gz", []string{isoLine("2026-06-11T08:00:00.000000+02:00", "B")})
	writeHistoryGzFixture(t, "packetfence.log.1.gz", []string{isoLine("2026-06-11T09:00:00.000000+02:00", "C")})
	if err := os.WriteFile(filepath.Join(historyLogDir, "packetfence.log"), []byte(""), 0644); err != nil {
		t.Fatal(err)
	}

	req.Cursor = resp.Cursor
	resp2, errMsg := runHistoryQuery(req, testAllowed)
	if errMsg != "" {
		t.Fatal(errMsg)
	}
	if len(resp2.Events) != 1 || !strings.Contains(resp2.Events[0].Data.Raw, "C") {
		raws := []string{}
		for _, ev := range resp2.Events {
			raws = append(raws, ev.Data.Raw)
		}
		t.Fatalf("poll2: line C lost or duplicated, got %v", raws)
	}
}

// Regression: a page boundary (event cap) landing exactly before a
// multi-line continuation must not drop the continuation on resume.
func TestHistoryContinuationAtPageBoundary(t *testing.T) {
	useHistoryFixtureDir(t)
	lines := []string{}
	for i := 0; i < historyMaxEvents; i++ {
		lines = append(lines, isoLine(fmt.Sprintf("2026-06-11T10:00:%02d.%06d+02:00", i/1000, (i%1000)*1000), fmt.Sprintf("e%d", i)))
	}
	lines = append(lines, "  continuation of last event")
	lines = append(lines, isoLine("2026-06-11T10:05:00.000000+02:00", "after"))
	writeHistoryFixture(t, "packetfence.log", lines)

	req := &historyRequest{Files: []string{"packetfence.log"},
		Start: "2026-06-11T00:00:00+02:00", End: "2026-06-12T00:00:00+02:00"}
	total := 0
	sawCont := false
	cursor := map[string]*historyCursor{}
	for page := 0; page < 5; page++ {
		req.Cursor = cursor
		resp, errMsg := runHistoryQuery(req, testAllowed)
		if errMsg != "" {
			t.Fatal(errMsg)
		}
		for _, ev := range resp.Events {
			total++
			if strings.Contains(ev.Data.Raw, "continuation") {
				sawCont = true
			}
		}
		cursor = resp.Cursor
		if len(resp.Events) == 0 && !resp.Truncated {
			break
		}
	}
	if !sawCont {
		t.Errorf("continuation line lost at page boundary (total events %d, want %d)", total, historyMaxEvents+2)
	}
}

// Regression: the sig of a file smaller than historySigBytes must remain
// valid after the file grows — otherwise resume degrades to the timestamp
// fallback and a new line sharing the last-scanned millisecond is lost.
func TestHistorySmallFileSigStability(t *testing.T) {
	useHistoryFixtureDir(t)
	l1 := isoLine("2026-06-11T10:00:00.000000+02:00", "one")
	writeHistoryFixture(t, "packetfence.log", []string{l1})

	req := &historyRequest{Files: []string{"packetfence.log"},
		Start: "2026-06-11T00:00:00+02:00", End: "2026-06-12T00:00:00+02:00"}
	resp, errMsg := runHistoryQuery(req, testAllowed)
	if errMsg != "" {
		t.Fatal(errMsg)
	}
	if len(resp.Events) != 1 {
		t.Fatalf("poll1: want 1, got %d", len(resp.Events))
	}

	// The file grows past historySigBytes; the second line shares the
	// millisecond with the line already delivered.
	l2 := isoLine("2026-06-11T10:00:00.000000+02:00", "two same ms")
	l3 := isoLine("2026-06-11T10:00:01.000000+02:00", "three")
	writeHistoryFixture(t, "packetfence.log", []string{l1, l2, l3})

	req.Cursor = resp.Cursor
	resp2, errMsg := runHistoryQuery(req, testAllowed)
	if errMsg != "" {
		t.Fatal(errMsg)
	}
	got := []string{}
	for _, ev := range resp2.Events {
		got = append(got, ev.Data.Meta.LogWithoutPrefix)
	}
	if len(resp2.Events) != 2 {
		t.Fatalf("poll2: want lines two+three, got %v", got)
	}
}

// A single line with an absurdly future timestamp must not hide every later
// line of the file.
func TestHistoryAnomalousFutureTimestamp(t *testing.T) {
	useHistoryFixtureDir(t)
	writeHistoryFixture(t, "packetfence.log", []string{
		isoLine("2026-06-11T10:00:00.000000+02:00", "sane one"),
		isoLine("2099-01-01T00:00:00.000000+02:00", "from the future"),
		isoLine("2026-06-11T10:00:02.000000+02:00", "sane two"),
	})

	req := &historyRequest{Files: []string{"packetfence.log"},
		Start: "2026-06-11T00:00:00+02:00", End: "2026-06-12T00:00:00+02:00"}
	resp, errMsg := runHistoryQuery(req, testAllowed)
	if errMsg != "" {
		t.Fatal(errMsg)
	}
	if len(resp.Events) != 2 {
		raws := []string{}
		for _, ev := range resp.Events {
			raws = append(raws, ev.Data.Raw)
		}
		t.Fatalf("expected both sane lines, got %v", raws)
	}
}

// A cursor is client JSON: a forged sig_len must not become an unbounded
// allocation or decompression outside the scan budgets.
func TestHistoryForgedSigLenClamped(t *testing.T) {
	useHistoryFixtureDir(t)
	writeHistoryFixture(t, "packetfence.log", []string{
		isoLine("2026-06-11T10:00:00.000000+02:00", "one"),
		isoLine("2026-06-11T10:00:01.000000+02:00", "two"),
	})

	req := &historyRequest{
		Files: []string{"packetfence.log"},
		Start: "2026-06-11T00:00:00+02:00", End: "2026-06-12T00:00:00+02:00",
		Cursor: map[string]*historyCursor{
			"packetfence.log": {Source: 0, Offset: 0, Sig: "deadbeef", SigLen: 1 << 30, TsMs: 0},
		},
	}
	begin := time.Now()
	resp, errMsg := runHistoryQuery(req, testAllowed)
	if errMsg != "" {
		t.Fatal(errMsg)
	}
	if elapsed := time.Since(begin); elapsed > 2*time.Second {
		t.Errorf("forged sig_len took %s", elapsed)
	}
	// Clamped to the TsMs fallback (0): the full window is delivered.
	if len(resp.Events) != 2 {
		t.Errorf("expected ts-floor fallback to deliver both lines, got %d", len(resp.Events))
	}
}
