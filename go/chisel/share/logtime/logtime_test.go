package logtime

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestParse(t *testing.T) {
	loc := time.FixedZone("EDT", -4*3600)
	want := time.Date(2026, 10, 26, 14, 7, 44, 0, loc)
	for _, line := range []string{
		"2026/10/26 14:07:44 [pfconnector/IVK7lf4v6K-004722] \"GET http://127.0.0.1:8081/",
		"Mon Oct 26 14:07:44 2026 : Auth: (1159) Login OK: [02005e104012]",
		"Mon Oct 26 14:07:44 2026: Reload complete",
		"[GIN] 2026/10/26 - 14:07:44 | 200 |     122.107µs |       127.0.0.1 | GET",
		"[2026-10-26 14:07:44] Upgrade to 16.0 completed",
	} {
		got, ok := Parse(line, loc)
		if !ok || !got.Equal(want) {
			t.Errorf("Parse(%q) = %s, %v, want %s", line, got, ok, want)
		}
	}
	for _, line := range []string{"", "0 upgraded, 0 newly installed", "  continuation of a stack trace", "[GIN-debug] Listening"} {
		if got, ok := Parse(line, loc); ok {
			t.Errorf("Parse(%q) = %s, want no timestamp", line, got)
		}
	}
}

func TestLinesSince(t *testing.T) {
	loc := time.UTC
	path := filepath.Join(t.TempDir(), "test.log")
	content := strings.Join([]string{
		"2026/10/26 14:00:00 first",
		"2026/10/26 14:05:00 second",
		"  continuation of second",
		"2026/10/26 14:10:00 third",
		"  continuation of third",
		"2026/10/26 14:15:00 fourth",
	}, "\n") + "\n"
	if err := os.WriteFile(path, []byte(content), 0600); err != nil {
		t.Fatal(err)
	}

	lines, found, err := LinesSince(path, time.Date(2026, 10, 26, 14, 7, 0, 0, loc), 10, loc)
	if err != nil || !found {
		t.Fatalf("LinesSince: found %v, err %v", found, err)
	}
	want := []string{"2026/10/26 14:10:00 third", "  continuation of third", "2026/10/26 14:15:00 fourth"}
	if strings.Join(lines, "\n") != strings.Join(want, "\n") {
		t.Errorf("lines since 14:07:\n%s\nwant\n%s", strings.Join(lines, "\n"), strings.Join(want, "\n"))
	}

	// the cap applies
	lines, _, _ = LinesSince(path, time.Date(2026, 10, 26, 13, 0, 0, 0, loc), 2, loc)
	if len(lines) != 2 || lines[0] != "2026/10/26 14:00:00 first" {
		t.Errorf("capped lines: %q", lines)
	}

	// nothing that recent
	if lines, found, _ := LinesSince(path, time.Date(2026, 10, 26, 15, 0, 0, 0, loc), 10, loc); found || len(lines) != 0 {
		t.Errorf("lines since 15:00: %q, found %v", lines, found)
	}
}
