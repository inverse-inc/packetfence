package pfsso

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/julienschmidt/httprouter"
)

type nextHandler struct{ called bool }

func (n *nextHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) error {
	n.called = true
	return nil
}

func TestPfssoFallthrough(t *testing.T) {
	router := httprouter.New()
	router.POST("/api/v1/firewall_sso/update", func(w http.ResponseWriter, r *http.Request, p httprouter.Params) { w.WriteHeader(http.StatusAccepted) })
	h := PfssoHandler{router: router}
	for _, tc := range []struct {
		method, path string
		status       int
		next         bool
	}{
		{http.MethodPost, "/api/v1/firewall_sso/update", http.StatusAccepted, false},
		{http.MethodPost, "/api/v1/firewall_sso/x", http.StatusNotFound, false},
		{http.MethodGet, "/api/v1/firewall_sso/update", http.StatusMethodNotAllowed, false},
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
