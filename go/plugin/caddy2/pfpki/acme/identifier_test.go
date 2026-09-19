package acme

import (
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	chi "github.com/go-chi/chi/v5"
)

// TestValidateIdentifier pins the input gate that keeps an order's
// identifier from becoming an SSRF primitive in http-01 (the value used
// to be dropped straight into "http://"+value+"/.well-known/...").
func TestValidateIdentifier(t *testing.T) {
	cases := []struct {
		typ, value string
		ok         bool
	}{
		{"dns", "radius.example.test", true},
		{"dns", "RADIUS.Example.TEST", true},
		{"dns", "host", true},
		{"dns", "a-b.c1.example", true},
		{"dns", "", false},
		{"dns", "127.0.0.1:22225/api/v1/pki/checkrenewal?x=", false},
		{"dns", "example.test/path", false},
		{"dns", "example.test:8080", false},
		{"dns", "user@example.test", false},
		{"dns", "*.example.test", false},
		{"dns", "-bad.example", false},
		{"dns", "bad-.example", false},
		{"dns", "a..b", false},
		{"dns", "127.0.0.1", false},
		{"dns", "[::1]", false},
		{"dns", strings.Repeat("a", 64) + ".example", false},
		{"ip", "10.1.2.3", true},
		{"ip", "192.168.0.10", true},
		{"ip", "2001:db8::10", true},
		{"ip", "127.0.0.1", false},
		{"ip", "::1", false},
		{"ip", "0.0.0.0", false},
		{"ip", "169.254.169.254", false},
		{"ip", "224.0.0.1", false},
		{"ip", "255.255.255.255", false},
		{"ip", "fe80::1", false},
		{"ip", "not-an-ip", false},
		{"permanent-identifier", "00008101-001AABCDEF01", true},
		{"permanent-identifier", "C02XY1234567", true},
		{"permanent-identifier", "tab\tbad", false},
		{"permanent-identifier", "ünïcode", false},
		{"permanent-identifier", strings.Repeat("x", 256), false},
		{"email", "user@example.test", false},
		{"bogus", "x", false},
	}
	for _, c := range cases {
		err := validateIdentifier(c.typ, c.value)
		if c.ok && err != nil {
			t.Errorf("%s %q: unexpected error %v", c.typ, c.value, err)
		}
		if !c.ok && err == nil {
			t.Errorf("%s %q: expected rejection", c.typ, c.value)
		}
	}
}

func TestHTTP01AllowedIP(t *testing.T) {
	for ip, want := range map[string]bool{
		"10.0.0.1":         true,
		"172.16.5.5":       true,
		"8.8.8.8":          true,
		"2001:db8::1":      true,
		"fd00::1":          true,
		"127.0.0.1":        false,
		"127.1.2.3":        false,
		"::1":              false,
		"0.0.0.0":          false,
		"0.1.2.3":          false,
		"::":               false,
		"169.254.1.1":      false,
		"fe80::1":          false,
		"224.0.0.1":        false,
		"ff02::1":          false,
		"255.255.255.255":  false,
		"::ffff:127.0.0.1": false,
	} {
		if got := http01AllowedIP(net.ParseIP(ip)); got != want {
			t.Errorf("%s: got %v want %v", ip, got, want)
		}
	}
	if http01AllowedIP(nil) {
		t.Errorf("nil ip must be refused")
	}
}

// TestHTTP01URL checks the challenge URL is built from an authority we
// control, never from string concatenation of the identifier.
func TestHTTP01URL(t *testing.T) {
	cases := []struct {
		identifier, want string
		ok               bool
	}{
		{"radius.example.test", "http://radius.example.test/.well-known/acme-challenge/tok", true},
		{"10.1.2.3", "http://10.1.2.3/.well-known/acme-challenge/tok", true},
		{"2001:db8::10", "http://[2001:db8::10]/.well-known/acme-challenge/tok", true},
		{"127.0.0.1", "", false},
		{"127.0.0.1:22225/api/v1/pki/checkrenewal?x=", "", false},
		{"example.test:81", "", false},
		{"user:pw@example.test", "", false},
	}
	for _, c := range cases {
		got, err := http01URL(c.identifier, "tok")
		if c.ok && (err != nil || got != c.want) {
			t.Errorf("%q: got %q err=%v want %q", c.identifier, got, err, c.want)
		}
		if !c.ok && err == nil {
			t.Errorf("%q: expected rejection, got %q", c.identifier, got)
		}
	}
}

// TestHTTP01ClientRefusesLoopback runs the production transport against
// a listener on 127.0.0.1: the dial must be refused before any bytes
// are sent, whatever the identifier resolved to.
func TestHTTP01ClientRefusesLoopback(t *testing.T) {
	hit := false
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { hit = true }))
	defer srv.Close()
	client := newHTTP01Client()
	_, err := client.Get(srv.URL + "/.well-known/acme-challenge/tok")
	if err == nil {
		t.Fatalf("expected the dial to be refused")
	}
	if hit {
		t.Fatalf("loopback listener was reached: %v", err)
	}
	// The refusal comes from the port check (httptest picks a high
	// port) or the address check; either way it is ours, not a
	// connection error.
	if !strings.Contains(err.Error(), "http-01:") {
		t.Fatalf("unexpected error: %v", err)
	}
}

// TestAcmeMountPath covers profile names that are a prefix of a later
// path segment ("a" vs "/account", "pki" vs "/pki/acme"), which the
// previous last-index search got wrong.
func TestAcmeMountPath(t *testing.T) {
	var got string
	capture := func(w http.ResponseWriter, r *http.Request) { got = acmeMountPath(r) }
	sub := chi.NewRouter()
	sub.Route("/{profile}", func(r chi.Router) {
		r.Get("/directory", capture)
		r.Get("/account/{id}", capture)
		r.Get("/order/{id}/finalize", capture)
	})
	root := chi.NewRouter()
	root.Route("/api/v1", func(r chi.Router) {
		r.Mount("/pki/acme", sub)
	})
	root.Mount("/acme", sub)

	cases := []struct{ path, want string }{
		{"/api/v1/pki/acme/a/account/7", "/api/v1/pki/acme"},
		{"/api/v1/pki/acme/a/directory", "/api/v1/pki/acme"},
		{"/api/v1/pki/acme/pki/order/3/finalize", "/api/v1/pki/acme"},
		{"/api/v1/pki/acme/acme/account/1", "/api/v1/pki/acme"},
		{"/api/v1/pki/acme/new/account/1", "/api/v1/pki/acme"},
		{"/api/v1/pki/acme/radius-lab/order/12/finalize", "/api/v1/pki/acme"},
		{"/acme/a/account/7", "/acme"},
		{"/acme/acme/directory", "/acme"},
	}
	for _, c := range cases {
		got = ""
		rec := httptest.NewRecorder()
		root.ServeHTTP(rec, httptest.NewRequest("GET", c.path, nil))
		if rec.Code != http.StatusOK {
			t.Errorf("%s: route not matched (%d)", c.path, rec.Code)
			continue
		}
		if got != c.want {
			t.Errorf("%s: got %q want %q", c.path, got, c.want)
		}
	}
}
