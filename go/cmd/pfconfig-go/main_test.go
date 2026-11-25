package main

import (
	"context"
	"encoding/binary"
	"encoding/json"
	"io"
	"log/slog"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/cache"
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/manager"
)

func startServer(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	files := map[string]string{
		"floating_network_device.conf": "[11:22:33:44:55:66]\nip=10.0.0.1\ntrunkPort=yes\n\n[aa:bb:cc:dd:ee:ff]\nip=10.0.0.2\n",
		"cloud.conf":                   "",
		"ssl.conf":                     "",
	}
	for name, content := range files {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	c := cache.NewShardedCache[string, any](1, 32, cache.HashString)
	t.Cleanup(c.Close)
	m := manager.NewManager(logger, dir, c)
	if err := m.LoadConfigs(context.Background()); err != nil {
		t.Fatal(err)
	}
	sock := filepath.Join(dir, "pfconfig.sock")
	l, err := net.Listen("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { l.Close() })
	go runServer(context.Background(), logger, l, m) //nolint:errcheck
	return sock
}

// query sends a request like the Perl client (one JSON line, connection kept open)
// and decodes the length prefixed answer.
func query(t *testing.T, sock string, line string) map[string]any {
	t.Helper()
	c, err := net.Dial("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	_ = c.SetDeadline(time.Now().Add(2 * time.Second))
	if _, err := c.Write([]byte(line + "\n")); err != nil {
		t.Fatal(err)
	}
	var header [4]byte
	if _, err := io.ReadFull(c, header[:]); err != nil {
		t.Fatalf("no answer for %s: %v", line, err)
	}
	body := make([]byte, binary.LittleEndian.Uint32(header[:]))
	if _, err := io.ReadFull(c, body); err != nil {
		t.Fatal(err)
	}
	var out map[string]any
	if err := json.Unmarshal(body, &out); err != nil {
		t.Fatalf("bad answer %q: %v", body, err)
	}
	return out
}

func TestServerProtocol(t *testing.T) {
	sock := startServer(t)

	// tied hash iteration (FIRSTKEY/NEXTKEY)
	var got []any
	last := ""
	for i := 0; i < 5; i++ {
		r := query(t, sock, `{"method":"next_key","key":"config::FloatingDevices()","last_key":"`+last+`","encoding":"json"}`)
		if r["next_key"] == nil {
			break
		}
		last = r["next_key"].(string)
		got = append(got, last)
	}
	if len(got) != 2 {
		t.Fatalf("next_key iteration returned %v", got)
	}

	// EXISTS
	if r := query(t, sock, `{"method":"key_exists","key":"config::FloatingDevices()","search":"aa:bb:cc:dd:ee:ff","encoding":"json"}`); r["result"] != float64(1) {
		t.Fatalf("key_exists: %v", r)
	}

	// FETCH of an unknown key answers undef instead of closing the connection
	if r := query(t, sock, `{"method":"hash_element","key":"config::FloatingDevices();nope","encoding":"json"}`); r["element"] != nil {
		t.Fatalf("unknown key: %v", r)
	}

	// a method on the wrong namespace type answers instead of crashing the server
	query(t, sock, `{"method":"keys","key":"resource::Test()","encoding":"json"}`)
	if r := query(t, sock, `{"method":"element","key":"resource::Test()","encoding":"json"}`); r["element"] != "10.0.0.1" {
		t.Fatalf("server not answering after a bad request: %v", r)
	}

	// a request of exactly 1024 bytes (the old read buffer size) must not hang
	base := `{"method":"hash_element","key":"config::FloatingDevices();11:22:33:44:55:66","encoding":"json","search":""}`
	line := strings.Replace(base, `"search":""`, `"search":"`+strings.Repeat("x", 1024-len(base)-1)+`"`, 1)
	if len(line)+1 != 1024 {
		t.Fatalf("bad test request size %d", len(line)+1)
	}
	if r := query(t, sock, line); r["element"].(map[string]any)["trunkPort"] != "1" {
		t.Fatalf("1024 bytes request: %v", r)
	}
}

func TestRequestTimeout(t *testing.T) {
	sock := startServer(t)
	c, err := net.Dial("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	_ = c.SetDeadline(time.Now().Add(requestTimeout + 2*time.Second))
	// never send anything: the server must close the connection
	if _, err := c.Read(make([]byte, 1)); err != io.EOF {
		t.Fatalf("expected the server to close the idle connection, got %v", err)
	}
}
