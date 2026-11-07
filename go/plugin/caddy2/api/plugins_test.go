package api

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"github.com/inverse-inc/packetfence/go/uiplugins"
	"github.com/julienschmidt/httprouter"
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
    "search": "items/search",
    "item": "items/{id}",
    "create": {"path": "items", "can": "create syslog"},
    "update": {"path": "items/{id}", "can": "update syslog"}
  },
  "form": {"fields": [{"namespace": "id", "component": "BaseFormGroupInput"}]}
}`

type pluginRequest struct {
	Method, Path, Query, Body string
	Header                    http.Header
}

// a plugin service: its manifest, and every other request echoed
func testPlugin(t *testing.T, seen *[]pluginRequest) uiplugins.Registration {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == uiplugins.ManifestPath {
			w.Write([]byte(pluginManifest))
			return
		}
		b, _ := io.ReadAll(r.Body)
		*seen = append(*seen, pluginRequest{r.Method, r.URL.Path, r.URL.RawQuery, string(b), r.Header.Clone()})
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("X-Plugin", "acme")
		w.WriteHeader(http.StatusCreated)
		w.Write([]byte(`{"ok":true}`))
	}))
	t.Cleanup(server.Close)
	host, port, _ := net.SplitHostPort(server.Listener.Addr().String())
	p, _ := strconv.Atoi(port)
	return uiplugins.Registration{Name: "acme", Host: host, Port: p}
}

func withRegistrations(t *testing.T, list func(context.Context, *sql.DB) (map[string]uiplugins.Registration, error)) {
	saved := listPluginRegistrations
	listPluginRegistrations = list
	pluginRegistrations.reset()
	t.Cleanup(func() {
		listPluginRegistrations = saved
		pluginRegistrations.reset()
	})
}

func testRouter() *httprouter.Router {
	h := &APIHandler{}
	router := httprouter.New()
	router.GET("/api/v1/plugins", h.plugins)
	for _, method := range uiplugins.ProxyMethods {
		router.Handle(method, "/api/v1/plugin/:name/*path", h.pluginProxy)
	}
	return router
}

func TestPlugins(t *testing.T) {
	seen := []pluginRequest{}
	acme := testPlugin(t, &seen)
	router := testRouter()
	saved := pluginAdminActions
	defer func() { pluginAdminActions = saved }()
	// the admin role "syslog reader" has the action SYSLOG_READ
	pluginAdminActions = func(ctx context.Context, roles []string) map[string]bool {
		if len(roles) == 1 && roles[0] == "syslog reader" {
			return map[string]bool{"SYSLOG_READ": true}
		}
		return map[string]bool{}
	}
	role := "syslog reader"

	get := func() []uiplugins.Plugin {
		w := httptest.NewRecorder()
		r := httptest.NewRequest("GET", "/api/v1/plugins", nil)
		r.Header.Set("X-PacketFence-Admin-Roles", role)
		router.ServeHTTP(w, r)
		body := struct {
			Items  []uiplugins.Plugin `json:"items"`
			Status int                `json:"status"`
		}{}
		if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
			t.Fatalf("invalid answer %q: %s", w.Body.String(), err)
		}
		if body.Status != 200 || body.Items == nil {
			t.Fatalf("unexpected answer %q", w.Body.String())
		}
		return body.Items
	}

	withRegistrations(t, func(context.Context, *sql.DB) (map[string]uiplugins.Registration, error) {
		return map[string]uiplugins.Registration{"acme": acme}, nil
	})
	if items := get(); len(items) != 1 || items[0].ID != "acme" {
		t.Errorf("expected the acme plugin, got %+v", items)
	}
	// an admin without its menu.can does not get its manifest
	role = "NONE"
	if items := get(); len(items) != 0 {
		t.Errorf("expected no plugin without read syslog, got %+v", items)
	}
	role = "syslog reader"

	// database unavailable: an empty list, the UI works without plugins
	withRegistrations(t, func(context.Context, *sql.DB) (map[string]uiplugins.Registration, error) {
		return nil, errors.New("database unavailable")
	})
	if items := get(); len(items) != 0 {
		t.Errorf("expected no plugin, got %+v", items)
	}
}

func TestPluginProxyLookup(t *testing.T) {
	seen := []pluginRequest{}
	acme := testPlugin(t, &seen)
	withRegistrations(t, func(context.Context, *sql.DB) (map[string]uiplugins.Registration, error) {
		return map[string]uiplugins.Registration{"acme": acme}, nil
	})
	saved := pluginAdminActions
	defer func() { pluginAdminActions = saved }()
	// the admin role "syslog reader" has the action SYSLOG_READ
	pluginAdminActions = func(ctx context.Context, roles []string) map[string]bool {
		if len(roles) == 1 && roles[0] == "syslog reader" {
			return map[string]bool{"SYSLOG_READ": true}
		}
		return map[string]bool{}
	}
	router := testRouter()
	for target, code := range map[string]int{"/api/v1/plugin/acme/items": 201, "/api/v1/plugin/unknown/items": 404} {
		r := httptest.NewRequest("GET", target, nil)
		r.Header.Set("X-PacketFence-Admin-Roles", "syslog reader")
		w := httptest.NewRecorder()
		// like ServeHTTP: application/json by default
		w.Header().Set("Content-Type", "application/json")
		router.ServeHTTP(w, r)
		if w.Code != code {
			t.Errorf("%s: expected %d, got %d %s", target, code, w.Code, w.Body.String())
		}
		if ct := w.Header().Values("Content-Type"); len(ct) != 1 {
			t.Errorf("%s: Content-Type %v", target, ct)
		}
	}
	if len(seen) != 1 || seen[0].Path != "/items" || seen[0].Header.Get(uiplugins.ActionsHeader) != "SYSLOG_READ" {
		t.Errorf("unexpected requests to the plugin %+v", seen)
	}
}
