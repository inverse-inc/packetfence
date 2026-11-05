package uiplugins

import (
	"crypto/x509"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
)

const pluginManifest = `{
  "manifestVersion": 1,
  "id": "acme",
  "title": {"en": "Acme"},
  "menu": {"area": "configuration", "can": "read syslog"},
  "template": "collection",
  "collection": {"columns": [{"key": "id", "label": {"en": "Id"}}]},
  "api": {
    "list": "items",
    "listOptions": "items",
    "search": "items/search",
    "create": {"path": "items", "can": "create syslog"},
    "item": "items/{id}",
    "update": {"path": "items/{id}", "can": "update syslog"}
  },
  "form": {"fields": [{"namespace": "id", "component": "BaseFormGroupInput", "can": "read configuration_main"}]}
}`

type pluginRequest struct {
	Method, Path, Query, Body string
	Header                    http.Header
}

// a plugin service: its manifest, a JSON echo, and the answers a plugin must
// not pass to the admin (by item id)
func pluginHandler(seen *[]pluginRequest) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == ManifestPath {
			w.Header().Set("Content-Type", "application/json")
			w.Write([]byte(pluginManifest))
			return
		}
		b, _ := io.ReadAll(r.Body)
		*seen = append(*seen, pluginRequest{r.Method, r.URL.Path, r.URL.RawQuery, string(b), r.Header.Clone()})
		switch r.URL.Path {
		case "/items/html":
			w.Header().Set("Content-Type", "text/html")
			w.Write([]byte("<script>alert(1)</script>"))
			return
		case "/items/sniff":
			w.Write([]byte("<html><script>alert(1)</script></html>")) // no Content-Type
			return
		case "/items/redirect":
			http.Redirect(w, r, "https://evil.example/", http.StatusFound)
			return
		case "/items/unauthorized":
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			w.Write([]byte(`{"message":"login"}`))
			return
		case "/items/big":
			w.Header().Set("Content-Type", "application/json")
			w.Write([]byte(`"`))
			w.Write([]byte(strings.Repeat("a", maxProxyBody+10)))
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.Header().Set("Set-Cookie", "token=attacker; Path=/")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("X-Plugin", "acme")
		w.WriteHeader(http.StatusCreated)
		w.Write([]byte(`{"ok":true}`))
	})
}

func registrationOf(t *testing.T, name string, server *httptest.Server) Registration {
	host, port, _ := net.SplitHostPort(server.Listener.Addr().String())
	p, _ := strconv.Atoi(port)
	return Registration{Name: name, Host: host, Port: p}
}

// the routing of the caddy api handler: /api/v1/plugin/<name>/<path>, the
// admin of the test is in X-Test-Actions
func router(f *Fetcher, registrations map[string]Registration) func(w http.ResponseWriter, r *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		name, path, _ := strings.Cut(strings.TrimPrefix(r.URL.Path, "/api/v1/plugin/"), "/")
		registration, found := registrations[name]
		if !found {
			Error(w, http.StatusNotFound, "unknown")
			return
		}
		actions := map[string]bool{}
		for _, a := range strings.Split(r.Header.Get("X-Test-Actions"), ",") {
			actions[a] = true
		}
		f.Proxy(w, r, registration, "/"+path, IdentityOf(r, actions))
	}
}

func TestPluginProxy(t *testing.T) {
	seen := []pluginRequest{}
	server := httptest.NewServer(pluginHandler(&seen))
	defer server.Close()
	registrations := map[string]Registration{
		"acme": registrationOf(t, "acme", server),
		"down": {Name: "down", Host: "127.0.0.1", Port: 1},
	}
	route := router(NewFetcher(nil), registrations)

	do := func(method, target, actions, body string, headers ...string) *httptest.ResponseRecorder {
		r := httptest.NewRequest(method, target, strings.NewReader(body))
		r.Header.Set("Authorization", "Bearer admin-token")
		r.Header.Set("Cookie", "token=admin-token")
		// as api-aaa sets them
		r.Header.Set("X-PacketFence-Username", "admin")
		r.Header.Set("X-PacketFence-Admin-Roles", "ALL")
		r.Header.Set("X-Test-Actions", actions)
		r.Header.Set(ActionsHeader, "FORGED_BY_THE_CLIENT")
		for i := 0; i+1 < len(headers); i += 2 {
			r.Header[headers[i]] = []string{headers[i+1]}
		}
		w := httptest.NewRecorder()
		route(w, r)
		return w
	}

	all := "SYSLOG_READ,SYSLOG_CREATE,SYSLOG_UPDATE,CONFIGURATION_MAIN_READ,NODES_READ,USERS_READ"
	w := do("POST", "/api/v1/plugin/acme/items?x=1&y=a%20b", all, `{"id":"a"}`,
		"Connection", "close, X-PacketFence-Username, X-PacketFence-Admin-Roles",
		"X_PacketFence_Admin_Actions", "SPOOFED",
		"X-Packetfence-Admin_Roles", "ALL")
	if w.Code != http.StatusCreated || w.Body.String() != `{"ok":true}` {
		t.Fatalf("unexpected answer %d %q", w.Code, w.Body.String())
	}
	h := w.Header()
	if h.Get("Content-Type") != "application/json" || h.Get("X-Content-Type-Options") != "nosniff" || !strings.Contains(h.Get("Content-Security-Policy"), "sandbox") {
		t.Errorf("unexpected answer headers %v", h)
	}
	for _, header := range []string{"Set-Cookie", "Access-Control-Allow-Origin", "X-Plugin"} {
		if h.Get(header) != "" {
			t.Errorf("the plugin header %s reached the admin", header)
		}
	}
	if len(seen) != 1 {
		t.Fatalf("expected 1 request to the plugin, got %d", len(seen))
	}
	got := seen[0]
	if got.Method != "POST" || got.Path != "/items" || got.Query != "x=1&y=a%20b" || got.Body != `{"id":"a"}` {
		t.Errorf("unexpected request %+v", got)
	}
	for _, header := range []string{"Authorization", "Cookie", "X_PacketFence_Admin_Actions", "X-Packetfence-Admin_roles", "X-Test-Actions-Spoof"} {
		if len(got.Header.Values(header)) != 0 {
			t.Errorf("the header %s reached the plugin: %v", header, got.Header)
		}
	}
	for header := range got.Header {
		if isIdentityLike(header) && header != http.CanonicalHeaderKey(UsernameHeader) && header != http.CanonicalHeaderKey(RolesHeader) && header != http.CanonicalHeaderKey(ActionsHeader) {
			t.Errorf("an identity-like header reached the plugin: %s", header)
		}
	}
	// the identity survives a Connection header listing it; the actions are
	// the ones of the targets of the manifest
	if got.Header.Get(UsernameHeader) != "admin" || got.Header.Get(RolesHeader) != "ALL" ||
		got.Header.Get(ActionsHeader) != "CONFIGURATION_MAIN_READ,SYSLOG_CREATE,SYSLOG_READ,SYSLOG_UPDATE" {
		t.Errorf("unexpected identity headers: %v", got.Header)
	}

	for _, c := range []struct {
		method, target, actions string
		code                    int
	}{
		{"GET", "/api/v1/plugin/acme/items", "SYSLOG_READ", 201},
		{"HEAD", "/api/v1/plugin/acme/items/a", "SYSLOG_READ", 201},
		{"OPTIONS", "/api/v1/plugin/acme/items", "SYSLOG_READ", 201},
		{"POST", "/api/v1/plugin/acme/items/search", "SYSLOG_READ", 201}, // search is a read
		{"PATCH", "/api/v1/plugin/acme/items/a", "SYSLOG_READ,SYSLOG_UPDATE", 201},
		{"GET", "/api/v1/plugin/acme/items", "SYSTEM_READ", 403},                   // menu.can
		{"POST", "/api/v1/plugin/acme/items", "SYSLOG_READ", 403},                  // api.create.can
		{"PATCH", "/api/v1/plugin/acme/items/a", "SYSLOG_READ,SYSLOG_CREATE", 403}, // api.update.can
		{"DELETE", "/api/v1/plugin/acme/items/a", all + ",SYSLOG_DELETE", 403},     // no api.delete
		{"PUT", "/api/v1/plugin/acme/items/a", all, 403},                           // update is PATCH
		{"OPTIONS", "/api/v1/plugin/acme/items/a", all, 403},                       // no api.itemOptions
		{"GET", "/api/v1/plugin/acme/other", all, 403},                             // not an API path
		{"GET", "/api/v1/plugin/acme/items/a/b", all, 403},
		{"GET", "/api/v1/plugin/acme/items/..", all, 403},
		{"GET", "/api/v1/plugin/acme/items/.", all, 403},
		{"POST", "/api/v1/plugin/acme/items/search/x", all, 403},
		{"GET", "/api/v1/plugin/acme/items/html", all, 502},         // not JSON
		{"GET", "/api/v1/plugin/acme/items/sniff", all, 502},        // no Content-Type
		{"GET", "/api/v1/plugin/acme/items/redirect", all, 502},     // redirect
		{"GET", "/api/v1/plugin/acme/items/unauthorized", all, 502}, // would end the admin session
		{"GET", "/api/v1/plugin/acme/items/big", all, 502},          // larger than the limit
		{"GET", "/api/v1/plugin/unknown/items", all, 404},
		{"GET", "/api/v1/plugin/down/items", all, 502},
	} {
		w := do(c.method, c.target, c.actions, "")
		if w.Code != c.code {
			t.Errorf("%s %s with %s: expected %d, got %d %s", c.method, c.target, c.actions, c.code, w.Code, w.Body.String())
		}
		if w.Header().Get("Content-Type") != "application/json" || w.Header().Get("X-Content-Type-Options") != "nosniff" {
			t.Errorf("%s %s: answer headers %v", c.method, c.target, w.Header())
		}
		if strings.Contains(w.Body.String(), "<script>") {
			t.Errorf("%s %s: the plugin page reached the admin", c.method, c.target)
		}
	}

	// a request larger than the limit is refused
	w = do("POST", "/api/v1/plugin/acme/items", all, strings.Repeat("a", maxProxyBody+1))
	if w.Code != http.StatusRequestEntityTooLarge {
		t.Errorf("a request of %d bytes: %d", maxProxyBody+1, w.Code)
	}
}

// a plugin that is not on the loopback is reached over HTTPS, its certificate
// must chain to RootCAs
func TestPluginTLS(t *testing.T) {
	seen := []pluginRequest{}
	server := httptest.NewTLSServer(pluginHandler(&seen))
	defer server.Close()
	savedPlain, savedRoots, savedTransport := plainHTTP, RootCAs, pluginTransport
	defer func() { plainHTTP, RootCAs, pluginTransport = savedPlain, savedRoots, savedTransport }()
	plainHTTP = func(string) bool { return false }
	registration := registrationOf(t, "acme", server)
	if registration.BaseURL() != "https://"+server.Listener.Addr().String() {
		t.Fatalf("unexpected base URL %s", registration.BaseURL())
	}

	try := func(trusted bool) int {
		pool := x509.NewCertPool()
		if trusted {
			pool.AddCert(server.Certificate())
		}
		RootCAs = func() *x509.CertPool { return pool }
		pluginTransport = newTransport()
		f := NewFetcher(nil)
		w := httptest.NewRecorder()
		r := httptest.NewRequest("GET", "/api/v1/plugin/acme/items", nil)
		router(f, map[string]Registration{"acme": registration})(w, withActions(r, "SYSLOG_READ"))
		return w.Code
	}
	if code := try(true); code != http.StatusCreated {
		t.Errorf("trusted plugin certificate: %d", code)
	}
	if code := try(false); code != http.StatusBadGateway {
		t.Errorf("untrusted plugin certificate: %d", code)
	}
	if !IsLoopback("127.0.0.1") || !IsLoopback("::1") || !IsLoopback("localhost") || IsLoopback("10.0.0.1") || IsLoopback("plugin.example") {
		t.Error("IsLoopback")
	}
}

func withActions(r *http.Request, actions string) *http.Request {
	r.Header.Set("X-Test-Actions", actions)
	return r
}

func TestPathMatches(t *testing.T) {
	for _, c := range []struct {
		template, path string
		match          bool
	}{
		{"items/search", "/items/search", true},
		{"items/{id}", "/items/a", true},
		{"items/{id}", "/items/a/b", false},
		{"items/{id}", "/items/", false},
		{"items/{id}", "/items/..", false},
		{"items", "/items/search", false},
		{"items/search", "//items/search", false},
		{"items/search", "/items/search/", false},
	} {
		if pathMatches(c.template, c.path) != c.match {
			t.Errorf("%s %s: expected %v", c.template, c.path, c.match)
		}
	}
}
