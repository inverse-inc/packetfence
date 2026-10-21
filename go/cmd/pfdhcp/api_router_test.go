package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestAPIRouterJSONErrors(t *testing.T) {
	router := setupAPIRoutes(context.Background(), nil)
	for _, tc := range []struct {
		method, path string
		status       int
	}{
		{http.MethodGet, "/api/v1/dhcp/x", http.StatusNotFound},
		{http.MethodDelete, "/api/v1/dhcp/stats", http.StatusMethodNotAllowed},
	} {
		w := httptest.NewRecorder()
		router.ServeHTTP(w, httptest.NewRequest(tc.method, tc.path, nil))
		if w.Code != tc.status || w.Header().Get("Content-Type") != "application/json; charset=UTF-8" {
			t.Errorf("%s %s: got %d %q %s, expected a JSON %d", tc.method, tc.path, w.Code, w.Header().Get("Content-Type"), w.Body.String(), tc.status)
		}
	}
}
