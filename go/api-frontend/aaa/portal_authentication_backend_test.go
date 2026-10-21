package aaa

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
)

func TestPortalAuthenticationBackendAccessLevel(t *testing.T) {
	replies := map[string]string{
		"admin":   `{"pid":"bob","access_level":"ALL"}`,
		"null":    `{"pid":"bob","access_level":null}`,
		"empty":   `{"pid":"bob","access_level":" "}`,
		"none":    `{"pid":"bob","access_level":"NONE"}`,
		"missing": `{"pid":"bob","category":"default"}`,
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		reply, found := replies[r.URL.Query().Get("token")]
		if !found {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.Write([]byte(reply))
	}))
	defer server.Close()

	u, _ := url.Parse(server.URL)
	pab := &PortalAuthenticationBackend{PfAuthenticationBackend{url: u, httpClient: server.Client()}}
	ctx := context.Background()

	auth, tokenInfo, err := pab.Authenticate(ctx, "", "admin")
	if !auth || err != nil || tokenInfo == nil || !tokenInfo.AdminRoles["ALL"] || tokenInfo.Username != "bob" {
		t.Errorf("Expected a successful authentication with the ALL role, got %v %+v %v", auth, tokenInfo, err)
	}

	for _, token := range []string{"null", "empty", "none", "missing", "unknown"} {
		auth, tokenInfo, err := pab.Authenticate(ctx, "", token)
		if auth || tokenInfo != nil {
			t.Errorf("Token %s: expected the authentication to be refused, got %v %+v %v", token, auth, tokenInfo, err)
		}
	}
}
