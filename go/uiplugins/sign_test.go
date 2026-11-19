package uiplugins

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"
)

type signatureVector struct {
	SystemInitKey string `json:"system_init_key"`
	Name          string `json:"name"`
	ProxyKey      string `json:"proxy_key"`
	Timestamp     string `json:"timestamp"`
	Method        string `json:"method"`
	Path          string `json:"path"`
	Query         string `json:"query"`
	Username      string `json:"username"`
	Roles         string `json:"roles"`
	Actions       string `json:"actions"`
	Body          string `json:"body"`
	BodySHA256    string `json:"body_sha256"`
	Signature     string `json:"signature"`
}

func loadVector(t *testing.T) signatureVector {
	b, err := os.ReadFile("testdata/signature.json")
	if err != nil {
		t.Fatal(err)
	}
	var v signatureVector
	if err := json.Unmarshal(b, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func withSystemInitKey(t *testing.T, key string) {
	saved := SystemInitKey
	SystemInitKey = func() []byte { return []byte(key) }
	t.Cleanup(func() { SystemInitKey = saved })
}

// the shared vector: the same key and signature as pf::ui_plugins::proxy_key
// and the plugins compute
func TestSignatureVector(t *testing.T) {
	v := loadVector(t)
	withSystemInitKey(t, v.SystemInitKey)
	key := ProxyKey(v.Name)
	if hex.EncodeToString(key) != v.ProxyKey {
		t.Fatalf("proxy key %x, want %s", key, v.ProxyKey)
	}
	if got := BodySHA256([]byte(v.Body)); got != v.BodySHA256 {
		t.Fatalf("body sha256 %s, want %s", got, v.BodySHA256)
	}
	if got := Signature(key, SignedRequest{v.Timestamp, v.Method, v.Path, v.Query, v.Username, v.Roles, v.Actions, v.BodySHA256}); got != v.Signature {
		t.Fatalf("signature %s, want %s", got, v.Signature)
	}
}

// what a plugin receives: a signature it can check, the admin token for a
// bundle only
func TestProxySignsRequests(t *testing.T) {
	withSystemInitKey(t, "test-system-init-key")
	withBundles(t, "kit")
	for _, c := range []struct {
		manifest, name, path, actions string
		token                         bool
	}{
		{bundleManifest, "kit", "/api/v1/plugin/kit/files/upload?thread_id=3", "PLUGIN_READ,PLUGIN_WRITE", true},
		{pluginManifest, "acme", "/api/v1/plugin/acme/items/site%2Fa", "SYSLOG_READ,SYSLOG_UPDATE", false},
	} {
		var got *http.Request
		var body string
		manifest := c.manifest
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path == ManifestPath {
				w.Header().Set("Content-Type", "application/json")
				w.Write([]byte(manifest))
				return
			}
			got = r.Clone(context.Background())
			b, _ := io.ReadAll(r.Body)
			body = string(b)
			w.Header().Set("Content-Type", "application/json")
			w.Write([]byte(`{}`))
		}))
		registration := registrationOf(t, c.name, server)
		method := "POST"
		if !c.token {
			method = "PATCH"
		}
		r := httptest.NewRequest(method, c.path, strings.NewReader(`{"a":1}`))
		r.Header.Set("Authorization", "Bearer admin-token")
		r.Header.Set("X-PacketFence-Username", "admin")
		r.Header.Set("X-PacketFence-Admin-Roles", "ops,reader")
		r.Header.Set(SignatureHeader, "forged")
		r.Header.Set(AdminTokenHeader, "forged")
		actions := map[string]bool{}
		for _, a := range strings.Split(c.actions, ",") {
			actions[a] = true
		}
		path, _ := ProxyPath(r, c.name)
		w := httptest.NewRecorder()
		NewFetcher(nil).Proxy(w, r, registration, path, IdentityOf(r, actions), nil)
		server.Close()
		if got == nil {
			t.Fatalf("%s: not passed: %d %s", c.name, w.Code, w.Body)
		}
		ts := got.Header.Get(TimestampHeader)
		n, err := strconv.ParseInt(ts, 10, 64)
		if err != nil || time.Since(time.Unix(n, 0)) > time.Minute {
			t.Errorf("%s: timestamp %q", c.name, ts)
		}
		want := Signature(ProxyKey(c.name), SignedRequest{ts, got.Method, got.URL.EscapedPath(), got.URL.RawQuery,
			got.Header.Get(UsernameHeader), got.Header.Get(RolesHeader), got.Header.Get(ActionsHeader), BodySHA256([]byte(body))})
		if got.Header.Get(SignatureHeader) != want {
			t.Errorf("%s: signature %q, want %q", c.name, got.Header.Get(SignatureHeader), want)
		}
		if body != `{"a":1}` || got.Header.Get(RolesHeader) != "ops,reader" {
			t.Errorf("%s: body %q, roles %q", c.name, body, got.Header.Get(RolesHeader))
		}
		// another body or other roles: another signature
		other := SignedRequest{ts, got.Method, got.URL.EscapedPath(), got.URL.RawQuery,
			got.Header.Get(UsernameHeader), got.Header.Get(RolesHeader), got.Header.Get(ActionsHeader), BodySHA256([]byte(`{"a":2}`))}
		if Signature(ProxyKey(c.name), other) == want {
			t.Errorf("%s: the signature does not cover the body", c.name)
		}
		other.BodySHA256, other.Roles = BodySHA256([]byte(body)), "admin"
		if Signature(ProxyKey(c.name), other) == want {
			t.Errorf("%s: the signature does not cover the roles", c.name)
		}
		token := got.Header.Get(AdminTokenHeader)
		if c.token && token != "Bearer admin-token" {
			t.Errorf("%s: the bundle plugin got the token %q", c.name, token)
		}
		if !c.token && token != "" {
			t.Errorf("%s: a manifest plugin got the token %q", c.name, token)
		}
		if got.Header.Get("Authorization") != "" {
			t.Errorf("%s: Authorization passed", c.name)
		}
	}
}
