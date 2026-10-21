package unifiedapierrors

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestError(t *testing.T) {
	w := httptest.NewRecorder()
	Error(w, "Something failed", http.StatusBadRequest)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("unexpected status %d", w.Code)
	}
	if ct := w.Header().Get("Content-Type"); ct != "application/json; charset=UTF-8" {
		t.Fatalf("unexpected content type %q", ct)
	}
	var body UnifiedAPIError
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid JSON %q: %s", w.Body.String(), err)
	}
	if body.Status != http.StatusBadRequest || body.Message != "Something failed" {
		t.Fatalf("unexpected body %+v", body)
	}
}

func TestUnknownPathAndMethodNotAllowed(t *testing.T) {
	r := httptest.NewRequest(http.MethodDelete, "/api/v1/x", nil)
	w := httptest.NewRecorder()
	UnknownPath(w, r)
	if w.Code != http.StatusNotFound || w.Body.String() != `{"status":404,"message":"Unknown path /api/v1/x"}` {
		t.Fatalf("unexpected 404 reply %d %s", w.Code, w.Body.String())
	}
	w = httptest.NewRecorder()
	MethodNotAllowed(w, r)
	if w.Code != http.StatusMethodNotAllowed || w.Body.String() != `{"status":405,"message":"Method DELETE not allowed on /api/v1/x"}` {
		t.Fatalf("unexpected 405 reply %d %s", w.Code, w.Body.String())
	}
}

func TestOtherMethodMatches(t *testing.T) {
	r := httptest.NewRequest(http.MethodGet, "/api/v1/x", nil)
	if !OtherMethodMatches(r, func(method string) bool { return method == http.MethodPost }) {
		t.Fatal("a route with another method must be found")
	}
	if OtherMethodMatches(r, func(method string) bool { return method == http.MethodGet }) {
		t.Fatal("the method of the request isn't another method")
	}
}
