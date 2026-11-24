package handlers_test

import (
	"net/http"
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
)

// TestNonNumericIDIsRejected covers issue #9722: an {id} that isn't a
// number must never reach gorm as an inline condition, where it would be
// used as a raw WHERE clause. Each route answers 400 instead, except the
// download, which looks a non-numeric {id} up as a CN.
func TestNonNumericIDIsRejected(t *testing.T) {
	env := testutil.NewEnv(t)

	// NewEnv seeds the default SCEP server; add a second one so a
	// "1 OR 1=1" delete would have more than the requested row to remove.
	if err := env.DB.Create(&models.SCEPServer{Name: "other", URL: "http://other", SharedSecret: "s"}).Error; err != nil {
		t.Fatal(err)
	}

	const injected = "1%20OR%201=1"
	cases := []struct {
		method, path, body string
		want               int
	}{
		{http.MethodDelete, "/api/v1/pki/scepserver/" + injected, "", http.StatusBadRequest},
		{http.MethodPatch, "/api/v1/pki/ca/" + injected, "{}", http.StatusBadRequest},
		{http.MethodPost, "/api/v1/pki/ca/resign/" + injected, "{}", http.StatusBadRequest},
		{http.MethodPost, "/api/v1/pki/ca/csr/" + injected, "{}", http.StatusBadRequest},
		{http.MethodPatch, "/api/v1/pki/profile/" + injected, "{}", http.StatusBadRequest},
		{http.MethodPost, "/api/v1/pki/profile/" + injected + "/sign_csr", "{}", http.StatusBadRequest},
		{http.MethodPost, "/api/v1/pki/cert/" + injected + "/email", "{}", http.StatusBadRequest},
		{http.MethodPost, "/api/v1/pki/cert/resign/" + injected, "{}", http.StatusBadRequest},
		{http.MethodPatch, "/api/v1/pki/hsm/" + injected, "{}", http.StatusBadRequest},
		{http.MethodDelete, "/api/v1/pki/hsm/" + injected, "", http.StatusBadRequest},
		// The download turns a non-numeric {id} into a CN, passed to gorm
		// as a bind value: no certificate has that CN, so 404.
		{http.MethodPost, "/api/v1/pki/cert/" + injected + "/download", `{"password":"secret"}`, http.StatusNotFound},
	}
	for _, c := range cases {
		t.Run(c.method+" "+c.path, func(t *testing.T) {
			status, body := doJSON(t, env, c.method, c.path, c.body)
			if status != c.want {
				t.Fatalf("status = %d, want %d; body: %s", status, c.want, body)
			}
		})
	}

	var count int64
	env.DB.Model(&models.SCEPServer{}).Count(&count)
	if count != 2 {
		t.Fatalf("%d SCEP servers left, want 2", count)
	}
}
