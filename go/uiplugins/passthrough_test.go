package uiplugins

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

const bundleManifest = `{
  "manifestVersion": 1,
  "id": "kit",
  "title": {"en": "Kit"},
  "menu": {"area": "status", "can": "read plugin"},
  "template": "bundle",
  "bundle": {"hostApi": 1, "mounts": ["page", "navbar-panel"], "navbar": {"icon": "toolbox"}, "timeout": 2}
}`

// a bundle plugin service: its manifest, a JSON echo, a file, an HTML page, a
// slow answer
func bundleHandler(seen *[]pluginRequest, lock *sync.Mutex) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == ManifestPath {
			w.Header().Set("Content-Type", "application/json")
			w.Write([]byte(bundleManifest))
			return
		}
		b, _ := io.ReadAll(r.Body)
		lock.Lock()
		*seen = append(*seen, pluginRequest{r.Method, r.URL.Path, r.URL.RawQuery, string(b), r.Header.Clone(), r.URL.EscapedPath()})
		lock.Unlock()
		switch r.URL.Path {
		case "/files/1/download":
			w.Header().Set("Content-Type", "application/pdf")
			w.Header().Set("Content-Disposition", `inline; filename="report.pdf"`)
			w.Write([]byte("%PDF-1.7"))
			return
		case "/page":
			w.Header().Set("Content-Type", "text/html")
			w.Write([]byte("<script>alert(1)</script>"))
			return
		case "/redirect":
			http.Redirect(w, r, "https://evil.example/", http.StatusFound)
			return
		case "/slow":
			time.Sleep(3 * time.Second)
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Set-Cookie", "token=attacker; Path=/")
		w.Write([]byte(`{"ok":true}`))
	})
}

func TestBundleManifest(t *testing.T) {
	c := DefaultCatalog
	m, err := ParseManifest([]byte(bundleManifest))
	if err != nil {
		t.Fatal(err)
	}
	if err := m.Validate(c, "kit"); err != nil {
		t.Fatalf("a valid bundle: %s", err)
	}
	if m.PassthroughTimeout() != 2*time.Second {
		t.Fatalf("timeout %s", m.PassthroughTimeout())
	}
	for name, manifest := range map[string]string{
		"no bundle":            strings.Replace(bundleManifest, `"bundle": {"hostApi": 1, "mounts": ["page", "navbar-panel"], "navbar": {"icon": "toolbox"}, "timeout": 2}`, `"description": {"en": "x"}`, 1),
		"no hostApi":           strings.Replace(bundleManifest, `"hostApi": 1, `, ``, 1),
		"hostApi 2":            strings.Replace(bundleManifest, `"hostApi": 1`, `"hostApi": 2`, 1),
		"no mounts":            strings.Replace(bundleManifest, `"mounts": ["page", "navbar-panel"]`, `"mounts": []`, 1),
		"unknown mount":        strings.Replace(bundleManifest, `"page", "navbar-panel"`, `"page", "sidebar"`, 1),
		"mount twice":          strings.Replace(bundleManifest, `"page", "navbar-panel"`, `"page", "page", "navbar-panel"`, 1),
		"no navbar":            strings.Replace(bundleManifest, `"navbar": {"icon": "toolbox"}, `, ``, 1),
		"navbar no panel":      strings.Replace(bundleManifest, `["page", "navbar-panel"]`, `["page"]`, 1),
		"bad icon":             strings.Replace(bundleManifest, `"toolbox"`, `"Tool Box"`, 1),
		"an api":               strings.Replace(bundleManifest, `"bundle":`, `"api": {"item": "x"}, "bundle":`, 1),
		"a form":               strings.Replace(bundleManifest, `"bundle":`, `"form": {"fields": [{"namespace": "a", "component": "BaseFormGroupInput"}]}, "bundle":`, 1),
		"a long timeout":       strings.Replace(bundleManifest, `"timeout": 2`, `"timeout": 301`, 1),
		"bundle on a resource": strings.Replace(pluginManifest, `"template": "collection"`, `"template": "collection", "bundle": {}`, 1),
	} {
		id := "kit"
		if strings.Contains(manifest, `"acme"`) {
			id = "acme"
		}
		m, err := ParseManifest([]byte(manifest))
		if err == nil {
			err = m.Validate(c, id)
		}
		if err == nil {
			t.Errorf("%s: accepted", name)
		}
	}
	m, _ = ParseManifest([]byte(strings.Replace(bundleManifest, `, "timeout": 2`, ``, 1)))
	if m.PassthroughTimeout() != DefaultPassthroughTimeout*time.Second {
		t.Errorf("default timeout %s", m.PassthroughTimeout())
	}
}

func TestPassthroughProxy(t *testing.T) {
	seen := []pluginRequest{}
	var lock sync.Mutex
	server := httptest.NewServer(bundleHandler(&seen, &lock))
	defer server.Close()
	registrations := map[string]Registration{"kit": registrationOf(t, "kit", server)}
	f := NewFetcher(nil)
	readOnly := false
	route := func(w http.ResponseWriter, r *http.Request) {
		path, _ := ProxyPath(r, "kit")
		actions := map[string]bool{}
		for _, a := range strings.Split(r.Header.Get("X-Test-Actions"), ",") {
			actions[a] = true
		}
		f.Proxy(w, r, registrations["kit"], path, IdentityOf(r, actions), func(context.Context) bool { return readOnly })
	}
	do := func(method, target, actions, contentType, body string) *httptest.ResponseRecorder {
		r := httptest.NewRequest(method, target, strings.NewReader(body))
		r.Header.Set("Authorization", "Bearer admin-token")
		r.Header.Set("X-PacketFence-Username", "admin")
		r.Header.Set("X-PacketFence-Admin-Roles", "ops")
		r.Header.Set("X-Test-Actions", actions)
		if contentType != "" {
			r.Header.Set("Content-Type", contentType)
		}
		w := httptest.NewRecorder()
		route(w, r)
		return w
	}
	const read, write = "PLUGIN_READ", "PLUGIN_READ,PLUGIN_WRITE"

	for _, c := range []struct {
		method, path, actions string
		status                int
	}{
		{"GET", "/api/v1/plugin/kit/threads", read, 200},
		{"OPTIONS", "/api/v1/plugin/kit/threads", read, 200},
		{"GET", "/api/v1/plugin/kit/any/depth/path", read, 200},
		{"POST", "/api/v1/plugin/kit/messages", read, 403},
		{"POST", "/api/v1/plugin/kit/messages", write, 200},
		{"PUT", "/api/v1/plugin/kit/threads/1", write, 200},
		{"PATCH", "/api/v1/plugin/kit/threads/1", write, 200},
		{"DELETE", "/api/v1/plugin/kit/threads/1", read, 403},
		{"DELETE", "/api/v1/plugin/kit/threads/1", write, 200},
		{"GET", "/api/v1/plugin/kit/threads", "", 403},             // menu.can
		{"GET", "/api/v1/plugin/kit/threads", "PLUGIN_WRITE", 403}, // menu.can is read plugin
		{"GET", "/api/v1/plugin/kit/a/%2e%2e/b", read, 403},
		{"GET", "/api/v1/plugin/kit/a/./b", read, 403},
		{"GET", "/api/v1/plugin/kit/a%2F..%2F..%2Fb", read, 403}, // ".." behind an encoded "/"
		{"GET", "/api/v1/plugin/kit/files/site%2Fa", read, 200},  // an encoded "/" alone is fine
		{"GET", "/api/v1/plugin/kit/threads/", read, 200},
	} {
		if w := do(c.method, c.path, c.actions, "", ""); w.Code != c.status {
			t.Errorf("%s %s with %q: %d, want %d: %s", c.method, c.path, c.actions, w.Code, c.status, w.Body)
		}
	}

	// what the plugin gets: no token, the identity, the multipart body
	lock.Lock()
	seen = seen[:0]
	lock.Unlock()
	body := "--b\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.txt\"\r\n\r\nhello\r\n--b--\r\n"
	if w := do("POST", "/api/v1/plugin/kit/files/upload?thread_id=3", write, "multipart/form-data; boundary=b", body); w.Code != 200 {
		t.Fatalf("upload: %d %s", w.Code, w.Body)
	}
	lock.Lock()
	got := seen[0]
	lock.Unlock()
	if got.Path != "/files/upload" || got.Query != "thread_id=3" || got.Body != body ||
		got.Header.Get("Authorization") != "" || got.Header.Get(UsernameHeader) != "admin" ||
		!strings.HasPrefix(got.Header.Get("Content-Type"), "multipart/form-data") ||
		got.Header.Get(ActionsHeader) != "PLUGIN_READ,PLUGIN_WRITE" {
		t.Errorf("upload as the plugin got it: %+v", got)
	}

	// a JSON answer: JSON, the fixed headers
	w := do("GET", "/api/v1/plugin/kit/threads", read, "", "")
	if w.Header().Get("Content-Type") != "application/json" || w.Header().Get("Set-Cookie") != "" || w.Header().Get("Content-Disposition") != "" {
		t.Errorf("JSON answer headers: %v", w.Header())
	}
	// a file: its type, as a download
	w = do("GET", "/api/v1/plugin/kit/files/1/download", read, "", "")
	if w.Code != 200 || w.Header().Get("Content-Type") != "application/pdf" ||
		w.Header().Get("Content-Disposition") != `attachment; filename=report.pdf` || w.Body.String() != "%PDF-1.7" {
		t.Errorf("download: %d %v %q", w.Code, w.Header(), w.Body)
	}
	// a page: never rendered on the PacketFence origin
	w = do("GET", "/api/v1/plugin/kit/page", read, "", "")
	if w.Header().Get("Content-Disposition") != "attachment" || w.Header().Get("X-Content-Type-Options") != "nosniff" ||
		!strings.Contains(w.Header().Get("Content-Security-Policy"), "sandbox") {
		t.Errorf("HTML answer headers: %v", w.Header())
	}
	if w := do("GET", "/api/v1/plugin/kit/redirect", read, "", ""); w.Code != http.StatusBadGateway {
		t.Errorf("redirect: %d", w.Code)
	}
	// bundle.timeout
	if w := do("GET", "/api/v1/plugin/kit/slow", read, "", ""); w.Code != http.StatusBadGateway {
		t.Errorf("slow answer past bundle.timeout: %d", w.Code)
	}

	// read-only: writes refused, reads pass
	readOnly = true
	if w := do("POST", "/api/v1/plugin/kit/messages", write, "", ""); w.Code != 403 || !strings.Contains(w.Body.String(), "read-only") {
		t.Errorf("write in read-only: %d %s", w.Code, w.Body)
	}
	if w := do("GET", "/api/v1/plugin/kit/threads", read, "", ""); w.Code != 200 {
		t.Errorf("read in read-only: %d", w.Code)
	}
}

func TestManifestProxyReadOnly(t *testing.T) {
	seen := []pluginRequest{}
	server := httptest.NewServer(pluginHandler(&seen))
	defer server.Close()
	registration := registrationOf(t, "acme", server)
	f := NewFetcher(nil)
	do := func(method, target, actions string) int {
		r := httptest.NewRequest(method, target, strings.NewReader(`{}`))
		path, _ := ProxyPath(r, "acme")
		a := map[string]bool{}
		for _, x := range strings.Split(actions, ",") {
			a[x] = true
		}
		w := httptest.NewRecorder()
		f.Proxy(w, r, registration, path, IdentityOf(r, a), func(context.Context) bool { return true })
		return w.Code
	}
	all := "SYSLOG_READ,SYSLOG_CREATE,SYSLOG_UPDATE"
	for _, c := range []struct {
		method, path string
		status       int
	}{
		{"GET", "/api/v1/plugin/acme/items", 201},
		{"POST", "/api/v1/plugin/acme/items/search", 201}, // a search is a read
		{"POST", "/api/v1/plugin/acme/items", 403},        // create
		{"PATCH", "/api/v1/plugin/acme/items/a", 403},     // update
	} {
		if got := do(c.method, c.path, all); got != c.status {
			t.Errorf("read-only %s %s: %d, want %d", c.method, c.path, got, c.status)
		}
	}
}
