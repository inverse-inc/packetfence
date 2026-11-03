package aaa

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

func portalTestToken(name string) string {
	return strings.Repeat(name, 64/len(name))
}

func TestPortalAuthenticationBackendAccessLevel(t *testing.T) {
	replies := map[string]string{
		portalTestToken("a"):  `{"pid":"bob","access_level":"ALL"}`,
		portalTestToken("b"):  `{"pid":"bob","access_level":null}`,
		portalTestToken("c"):  `{"pid":"bob","access_level":" "}`,
		portalTestToken("d"):  `{"pid":"bob","access_level":"NONE"}`,
		portalTestToken("e"):  `{"pid":"bob","category":"default"}`,
		portalTestToken("0f"): `{"pid":"bob","access_level":"ALL"}`,
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.RawQuery != "" {
			t.Errorf("Expected no query string, got %s", r.URL.RawQuery)
		}
		reply, found := replies[strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")]
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

	auth, tokenInfo, err := pab.Authenticate(ctx, "", portalTestToken("a"))
	if !auth || err != nil || tokenInfo == nil || !tokenInfo.AdminRoles["ALL"] || tokenInfo.Username != "bob" {
		t.Errorf("Expected a successful authentication with the ALL role, got %v %+v %v", auth, tokenInfo, err)
	}

	for _, name := range []string{"b", "c", "d", "e", "1"} {
		auth, tokenInfo, err := pab.Authenticate(ctx, "", portalTestToken(name))
		if auth || tokenInfo != nil {
			t.Errorf("Token %s: expected the authentication to be refused, got %v %+v %v", name, auth, tokenInfo, err)
		}
	}
}

func TestPortalAuthenticationBackendIgnoresPasswords(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Errorf("Unexpected request to the portal: %s %s", r.URL, r.Header.Get("Authorization"))
		w.Write([]byte(`{"pid":"bob","access_level":"ALL"}`))
	}))
	defer server.Close()

	u, _ := url.Parse(server.URL)
	pab := &PortalAuthenticationBackend{PfAuthenticationBackend{url: u, httpClient: server.Client()}}
	ctx := context.Background()

	for _, c := range []struct{ username, password string }{
		{"admin", "secret"},
		{"admin", portalTestToken("a")},
		{"", "secret"},
		{"", "s3cr&t#x"},
		{"", strings.ToUpper(portalTestToken("a"))},
		{"", portalTestToken("a") + "0"},
		{"", portalTestToken("a") + "\n"},
	} {
		auth, tokenInfo, err := pab.Authenticate(ctx, c.username, c.password)
		if auth || tokenInfo != nil || err != nil {
			t.Errorf("%q/%q: expected to be skipped, got %v %+v %v", c.username, c.password, auth, tokenInfo, err)
		}
	}
}
