package api

import (
	"context"
	"encoding/json"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"github.com/inverse-inc/packetfence/go/uiplugins"
)

const uiPluginManifest = `{
  "manifestVersion": 1,
  "id": "acme",
  "title": {"en": "Acme"},
  "menu": {"area": "configuration"},
  "template": "resource",
  "api": {"item": "acme/settings"},
  "form": {"fields": [{"namespace": "name", "component": "BaseFormGroupInput"}]}
}`

func TestUiPlugins(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(uiPluginManifest))
	}))
	defer server.Close()
	host, port, _ := net.SplitHostPort(server.Listener.Addr().String())
	p, _ := strconv.Atoi(port)

	defer func(f func(context.Context) (map[string]uiplugins.Registration, error)) { uiPluginsRegistrations = f }(uiPluginsRegistrations)

	get := func() []uiplugins.Plugin {
		w := httptest.NewRecorder()
		APIHandler{}.uiPlugins(w, httptest.NewRequest("GET", "/api/v1/ui_plugins", nil), nil)
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

	uiPluginsRegistrations = func(context.Context) (map[string]uiplugins.Registration, error) {
		return map[string]uiplugins.Registration{
			"acme": {ID: "acme", Scheme: "http", Host: host, Port: p, ManifestPath: "/manifest.json"},
		}, nil
	}
	if items := get(); len(items) != 1 || items[0].ID != "acme" {
		t.Errorf("expected the acme plugin, got %+v", items)
	}

	// pfconfig unavailable: an empty list, the UI works without plugins
	uiPluginsRegistrations = func(context.Context) (map[string]uiplugins.Registration, error) {
		return nil, errors.New("pfconfig unavailable")
	}
	if items := get(); len(items) != 0 {
		t.Errorf("expected no plugin, got %+v", items)
	}
}
