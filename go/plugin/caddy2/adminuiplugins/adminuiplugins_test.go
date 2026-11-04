package adminuiplugins

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type nextHandler struct {
	called bool
}

func (n *nextHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) error {
	n.called = true
	w.WriteHeader(http.StatusTeapot)
	return nil
}

func TestServeHTTP(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, r.Method+" "+r.URL.Path+"?"+r.URL.RawQuery)
	}))
	defer upstream.Close()

	dead := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	deadURL := dead.URL
	dead.Close()

	plugins := map[string]pfconfigdriver.AdminUiPlugin{
		"demo":     {Enabled: "enabled", Upstream: upstream.URL + "/api/v1/demo"},
		"disabled": {Enabled: "disabled", Upstream: upstream.URL},
		"dead":     {Enabled: "enabled", Upstream: deadURL},
		"invalid":  {Enabled: "enabled", Upstream: "ftp://example.com"},
	}

	h := &AdminUiPlugins{
		proxies: &sync.Map{},
		lookup: func(ctx context.Context, id string) (pfconfigdriver.AdminUiPlugin, bool) {
			p, found := plugins[id]
			return p, found
		},
	}

	tests := []struct {
		path   string
		status int
		body   string
		next   bool
	}{
		{path: "/api/v1/plugins/demo/config/items?limit=1", status: http.StatusOK, body: "GET /api/v1/demo/config/items?limit=1"},
		{path: "/api/v1/plugins/demo/admin-ui", status: http.StatusOK, body: "GET /api/v1/demo/admin-ui?"},
		{path: "/api/v1/plugins/disabled/admin-ui", status: http.StatusNotFound},
		{path: "/api/v1/plugins/unknown/admin-ui", status: http.StatusNotFound},
		{path: "/api/v1/plugins/dead/admin-ui", status: http.StatusBadGateway},
		{path: "/api/v1/plugins/invalid/admin-ui", status: http.StatusBadGateway},
		{path: "/api/v1/nodes", status: http.StatusTeapot, next: true},
	}

	for _, test := range tests {
		next := &nextHandler{}
		w := httptest.NewRecorder()
		r := httptest.NewRequest(http.MethodGet, test.path, nil)
		if err := h.ServeHTTP(w, r, next); err != nil {
			t.Fatalf("%s: unexpected error %s", test.path, err)
		}

		if w.Code != test.status {
			t.Errorf("%s: expected status %d got %d", test.path, test.status, w.Code)
		}

		if test.body != "" && w.Body.String() != test.body {
			t.Errorf("%s: expected body %q got %q", test.path, test.body, w.Body.String())
		}

		if next.called != test.next {
			t.Errorf("%s: expected next called %t got %t", test.path, test.next, next.called)
		}
	}
}
