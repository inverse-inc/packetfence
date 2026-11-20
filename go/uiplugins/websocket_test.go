package uiplugins

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

// a bundle plugin service accepting WebSockets on /echo when its manifest
// declares bundle.websockets: it echoes the messages, after the headers it got
func webSocketPlugin(t *testing.T, id string, webSockets bool, seen *[]http.Header, lock *sync.Mutex) *httptest.Server {
	manifest := strings.Replace(bundleManifest, `"id": "kit"`, `"id": "`+id+`"`, 1)
	if webSockets {
		manifest = strings.Replace(manifest, `"timeout": 2}`, `"timeout": 1, "websockets": true}`, 1)
	}
	upgrader := websocket.Upgrader{}
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == ManifestPath {
			w.Header().Set("Content-Type", "application/json")
			w.Write([]byte(manifest))
			return
		}
		lock.Lock()
		*seen = append(*seen, r.Header.Clone())
		lock.Unlock()
		if r.URL.Path == "/page" {
			w.Header().Set("Content-Type", "text/html")
			w.Write([]byte("<script>alert(1)</script>"))
			return
		}
		conn, err := upgrader.Upgrade(w, r, http.Header{"Set-Cookie": {"token=attacker"}, "X-Plugin": {"1"}})
		if err != nil {
			return
		}
		defer conn.Close()
		for {
			kind, message, err := conn.ReadMessage()
			if err != nil {
				return
			}
			if err := conn.WriteMessage(kind, append([]byte("echo "), message...)); err != nil {
				return
			}
		}
	}))
}

func TestWebSocketProxy(t *testing.T) {
	withBundles(t, "kit", "kat")
	withSystemInitKey(t, "test init key")
	seen := []http.Header{}
	var lock sync.Mutex
	kit := webSocketPlugin(t, "kit", true, &seen, &lock)
	defer kit.Close()
	kat := webSocketPlugin(t, "kat", false, &seen, &lock)
	defer kat.Close()
	f := NewFetcher(nil)
	pf := httptest.NewServer(http.HandlerFunc(router(f, map[string]Registration{
		"kit": registrationOf(t, "kit", kit),
		"kat": registrationOf(t, "kat", kat),
	})))
	defer pf.Close()
	wsURL := "ws" + strings.TrimPrefix(pf.URL, "http")
	dial := func(path, origin, actions string) (*websocket.Conn, *http.Response, error) {
		h := http.Header{}
		if origin != "" {
			h.Set("Origin", origin)
		}
		h.Set("Cookie", "token=admin-token")
		h.Set("X-PacketFence-Username", "admin")
		h.Set("X-Test-Actions", actions)
		return websocket.DefaultDialer.Dial(wsURL+path, h)
	}

	conn, resp, err := dial("/api/v1/plugin/kit/echo?tail=10", pf.URL, "PLUGIN_READ")
	if err != nil {
		t.Fatalf("WebSocket refused: %s %v", err, resp)
	}
	if resp.Header.Get("Set-Cookie") != "" || resp.Header.Get("X-Plugin") != "" {
		t.Errorf("headers of the plugin passed: %v", resp.Header)
	}
	// longer than bundle.timeout: a WebSocket has none
	time.Sleep(1500 * time.Millisecond)
	if err := conn.WriteMessage(websocket.TextMessage, []byte("ls")); err != nil {
		t.Fatal(err)
	}
	if _, message, err := conn.ReadMessage(); err != nil || string(message) != "echo ls" {
		t.Errorf("echo: %q %v", message, err)
	}
	conn.Close()
	lock.Lock()
	got := seen[len(seen)-1]
	lock.Unlock()
	if got.Get("Cookie") != "" || got.Get(UsernameHeader) != "admin" || got.Get(SignatureHeader) == "" || got.Get(ActionsHeader) != "PLUGIN_READ" {
		t.Errorf("headers the plugin got: %v", got)
	}

	for _, c := range []struct {
		name, path, origin, actions string
		status                      int
	}{
		{"no Origin", "/api/v1/plugin/kit/echo", "", "PLUGIN_READ", http.StatusForbidden},
		{"another origin", "/api/v1/plugin/kit/echo", "https://evil.example", "PLUGIN_READ", http.StatusForbidden},
		{"no PLUGIN_READ", "/api/v1/plugin/kit/echo", pf.URL, "", http.StatusForbidden},
		{"no bundle.websockets", "/api/v1/plugin/kat/echo", pf.URL, "PLUGIN_READ", http.StatusBadRequest},
		{"not upgraded", "/api/v1/plugin/kit/page", pf.URL, "PLUGIN_READ", http.StatusOK},
	} {
		conn, resp, err := dial(c.path, c.origin, c.actions)
		if err == nil {
			conn.Close()
			t.Errorf("%s: WebSocket accepted", c.name)
			continue
		}
		if resp == nil || resp.StatusCode != c.status {
			t.Errorf("%s: %v, want %d", c.name, resp, c.status)
			continue
		}
		// a page the plugin answers instead is never rendered on the origin
		if c.status == http.StatusOK && resp.Header.Get("Content-Disposition") != "attachment" {
			t.Errorf("%s: answered as %v", c.name, resp.Header)
		}
	}
}

func TestWebSocketManifest(t *testing.T) {
	m, err := ParseManifest([]byte(strings.Replace(bundleManifest, `"timeout": 2}`, `"timeout": 2, "websockets": true}`, 1)))
	if err != nil {
		t.Fatal(err)
	}
	if err := m.Validate(DefaultCatalog, "kit"); err != nil || !m.Bundle.WebSockets {
		t.Errorf("bundle.websockets: %v %+v", err, m.Bundle)
	}
}
