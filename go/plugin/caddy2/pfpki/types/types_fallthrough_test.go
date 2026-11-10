package types

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
)

type nextHandler struct{ called bool }

func (n *nextHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) error {
	n.called = true
	return nil
}

func TestPkiFallthrough(t *testing.T) {
	router := chi.NewRouter()
	router.Get("/api/v1/pki/cas", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusAccepted) })
	h := Handler{Router: router}
	for _, tc := range []struct {
		method, path string
		status       int
		next         bool
	}{
		{http.MethodGet, "/api/v1/pki/cas", http.StatusAccepted, false},
		{http.MethodGet, "/api/v1/pki/x", http.StatusNotFound, false},
		{http.MethodDelete, "/api/v1/pki/cas", http.StatusMethodNotAllowed, false},
		{http.MethodGet, "/other", http.StatusOK, true},
	} {
		w := httptest.NewRecorder()
		next := &nextHandler{}
		h.ServeHTTP(w, httptest.NewRequest(tc.method, tc.path, nil), next)
		if w.Code != tc.status || next.called != tc.next {
			t.Errorf("%s %s: got %d (next called: %v), expected %d (next called: %v)", tc.method, tc.path, w.Code, next.called, tc.status, tc.next)
		}
	}
}
