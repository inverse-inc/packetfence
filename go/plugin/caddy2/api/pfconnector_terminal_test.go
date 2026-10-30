package api

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
)

func TestTerminalRedirectKeepsEscapedID(t *testing.T) {
	r := chi.NewRouter()
	r.Get("/api/v1/terminal/{connectorID}", APIHandler{}.redirectTerminal())
	req := httptest.NewRequest(http.MethodGet, "/api/v1/terminal/site%201", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusMovedPermanently || w.Header().Get("Location") != "/api/v1/terminal/site%201/" {
		t.Errorf("got %d to %q", w.Code, w.Header().Get("Location"))
	}
}
