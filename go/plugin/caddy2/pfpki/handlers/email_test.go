package handlers_test

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	chi "github.com/go-chi/chi/v5"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/handlers"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
)

// POST /pki/cert/{id}/email takes the optional password in a JSON body,
// so it doesn't end up in the logged URL.
func TestEmailCert_Post(t *testing.T) {
	env := testutil.NewEnv(t)
	r := chi.NewRouter()
	r.Post("/api/v1/pki/cert/{id}/email", handlers.EmailCert(env.Handler))

	for _, c := range []struct {
		body string
		want int
	}{
		{`{"password":`, http.StatusBadRequest},
		{`["password"]`, http.StatusBadRequest},
		// Accepted bodies reach the lookup of the (missing) certificate.
		{`{"password":"s3cret"}`, http.StatusNotFound},
		{`{}`, http.StatusNotFound},
		{``, http.StatusNotFound},
	} {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/pki/cert/999/email", strings.NewReader(c.body))
		req.Header.Set("Content-Type", "application/json")
		res := httptest.NewRecorder()
		r.ServeHTTP(res, req)
		if res.Code != c.want {
			t.Errorf("body %q: status %d, want %d (%s)", c.body, res.Code, c.want, res.Body.String())
		}
	}
}
