package api

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"testing"

	"github.com/inverse-inc/packetfence/go/uiplugins"
)

const bundleManifest = `{
  "manifestVersion": 1,
  "id": "kit",
  "title": {"en": "Kit"},
  "menu": {"area": "status", "can": "read plugin"},
  "template": "bundle",
  "bundle": {"hostApi": 1, "mounts": ["page"]}
}`

// GET /api/v1/plugins/<name>/bundle.js: the code of the package, to the
// admins who satisfy menu.can, only when it matches its sha256
func TestPluginBundle(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(bundleManifest))
	}))
	defer server.Close()
	host, port, _ := net.SplitHostPort(server.Listener.Addr().String())
	p, _ := strconv.Atoi(port)
	seen := []pluginRequest{}
	acme := testPlugin(t, &seen) // a manifest plugin: no bundle
	withRegistrations(t, func(context.Context, *sql.DB) (map[string]uiplugins.Registration, error) {
		return map[string]uiplugins.Registration{"kit": {Name: "kit", Host: host, Port: p}, "acme": acme}, nil
	})
	saved := pluginAdminActions
	defer func() { pluginAdminActions = saved }()
	pluginAdminActions = func(ctx context.Context, roles []string) map[string]bool {
		if len(roles) == 1 && roles[0] == "reader" {
			return map[string]bool{"PLUGIN_READ": true}
		}
		return map[string]bool{}
	}

	dir := t.TempDir()
	savedDir := uiplugins.PluginsConfDir
	uiplugins.PluginsConfDir = dir
	defer func() { uiplugins.PluginsConfDir = savedDir }()
	code := []byte(`export default { hostApi: 1, mount () {} }`)
	sum := sha256.Sum256(code)
	os.WriteFile(filepath.Join(dir, "kit.js"), code, 0644)
	os.WriteFile(filepath.Join(dir, "kit.conf"), []byte("[bundle]\nsha256="+hex.EncodeToString(sum[:])+"\n"), 0644)

	h := &APIHandler{}
	router := testRouter()
	router.GET("/api/v1/plugins/:name/bundle.js", h.pluginBundle)
	get := func(name, role string) *httptest.ResponseRecorder {
		w := httptest.NewRecorder()
		r := httptest.NewRequest("GET", "/api/v1/plugins/"+name+"/bundle.js", nil)
		r.Header.Set("X-PacketFence-Admin-Roles", role)
		router.ServeHTTP(w, r)
		return w
	}
	if w := get("kit", "reader"); w.Code != 200 || w.Body.String() != string(code) ||
		w.Header().Get("Content-Type") != "text/javascript; charset=utf-8" || w.Header().Get("X-Content-Type-Options") != "nosniff" {
		t.Errorf("bundle: %d %v %q", w.Code, w.Header(), w.Body)
	}
	if w := get("kit", "NONE"); w.Code != http.StatusForbidden {
		t.Errorf("bundle without menu.can: %d", w.Code)
	}
	if w := get("acme", "reader"); w.Code != http.StatusNotFound {
		t.Errorf("a manifest plugin has no bundle: %d", w.Code)
	}
	if w := get("other", "reader"); w.Code != http.StatusNotFound {
		t.Errorf("an unknown plugin: %d", w.Code)
	}
	os.WriteFile(filepath.Join(dir, "kit.js"), append(code, []byte("alert(1)")...), 0644)
	if w := get("kit", "reader"); w.Code != http.StatusNotFound {
		t.Errorf("a changed bundle is served: %d", w.Code)
	}
}

// the read-only state of the database is asked at most every pluginReadOnlyTTL
func TestPluginReadOnlyCache(t *testing.T) {
	saved := databaseReadOnly
	defer func() { databaseReadOnly = saved }()
	calls := 0
	databaseReadOnly = func(context.Context, *sql.DB) bool {
		calls++
		return true
	}
	c := &pluginReadOnlyCache{}
	db := func(context.Context) *sql.DB { return nil }
	for i := 0; i < 3; i++ {
		if !c.get(context.Background(), db) {
			t.Fatal("not read-only")
		}
	}
	if calls != 1 {
		t.Errorf("asked %d times, want 1", calls)
	}
	// no database handle: not read-only (the call fails on its own)
	if saved(context.Background(), nil) {
		t.Error("no database is read-only")
	}
}
