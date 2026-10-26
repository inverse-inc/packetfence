package chserver

import (
	"os"
	"path/filepath"
	"sync"
	"testing"
)

// resetPFVersionCache zeroes the sync.Once + cached string so a test
// can re-run readPFVersion() with a different pfReleaseFile. Package-
// private so only tests in this package can call it.
func resetPFVersionCache() {
	pfVersionOnce = sync.Once{}
	pfVersion = ""
}

// TestReadPFVersion exercises every branch of the pf-release parse:
// normal "PacketFence X.Y.Z" content, trailing whitespace, missing
// file (empty string returned), and the sync.Once cache (second
// read against a changed file returns the FIRST file's value).
func TestReadPFVersion(t *testing.T) {
	savedPath := pfReleaseFile
	defer func() {
		pfReleaseFile = savedPath
		resetPFVersionCache()
	}()

	cases := []struct {
		name    string
		content string
		want    string
	}{
		{"canonical form", "PacketFence 16.0.0\n", "16.0.0"},
		{"no trailing newline", "PacketFence 15.1.2", "15.1.2"},
		{"CRLF trailing", "PacketFence 15.2.0\r\n", "15.2.0"},
		{"X.Y only (no patch)", "PacketFence 15.1\n", "15.1"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			resetPFVersionCache()
			dir := t.TempDir()
			path := filepath.Join(dir, "pf-release")
			if err := os.WriteFile(path, []byte(tc.content), 0644); err != nil {
				t.Fatalf("write %s: %v", path, err)
			}
			pfReleaseFile = path
			if got := readPFVersion(); got != tc.want {
				t.Errorf("readPFVersion() = %q, want %q", got, tc.want)
			}
		})
	}

	t.Run("missing file returns empty", func(t *testing.T) {
		resetPFVersionCache()
		pfReleaseFile = filepath.Join(t.TempDir(), "does-not-exist")
		if got := readPFVersion(); got != "" {
			t.Errorf("readPFVersion() with missing file = %q, want empty", got)
		}
	})

	t.Run("sync.Once caches first read", func(t *testing.T) {
		resetPFVersionCache()
		dir := t.TempDir()
		path := filepath.Join(dir, "pf-release")
		if err := os.WriteFile(path, []byte("PacketFence 15.1.0\n"), 0644); err != nil {
			t.Fatalf("write %s: %v", path, err)
		}
		pfReleaseFile = path
		first := readPFVersion()
		if first != "15.1.0" {
			t.Fatalf("first read: got %q, want 15.1.0", first)
		}
		// Rewrite the file; cache MUST still return the first value.
		if err := os.WriteFile(path, []byte("PacketFence 99.9.9\n"), 0644); err != nil {
			t.Fatalf("rewrite %s: %v", path, err)
		}
		if got := readPFVersion(); got != first {
			t.Errorf("second read after file change: got %q, want %q (sync.Once must cache)", got, first)
		}
	})
}
