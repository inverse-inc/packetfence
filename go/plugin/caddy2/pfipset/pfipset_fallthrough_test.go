package pfipset

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gorilla/mux"
)

type nextHandler struct{ called bool }

func (n *nextHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) error {
	n.called = true
	return nil
}

func TestPfipsetFallthrough(t *testing.T) {
	// built like the real router: the routes are on a sub-router
	router := mux.NewRouter()
	api := router.PathPrefix("/api/v1").Subrouter()
	ok := func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusAccepted) }
	for _, path := range []string{"mark_layer3", "mark_layer2", "unmark_mac", "unmark_ip", "mark_ip_layer2", "mark_ip_layer3", "passthrough", "passthrough_isolation", "add_ip/{set_name}", "remove_ip/{set_name}"} {
		api.HandleFunc("/ipset/"+path, ok).Methods("POST")
	}
	h := PfipsetHandler{IPSET: &pfIPSET{}, router: router}
	for _, tc := range []struct {
		method, path string
		status       int
		next         bool
	}{
		{http.MethodPost, "/api/v1/ipset/mark_layer3", http.StatusAccepted, false},
		{http.MethodPost, "/api/v1/ipset/x", http.StatusNotFound, false},
		{http.MethodGet, "/api/v1/ipset/mark_layer3", http.StatusMethodNotAllowed, false},
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
