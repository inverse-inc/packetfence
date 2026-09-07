package api

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGottyAuthTokenJS(t *testing.T) {
	good := []string{
		"var gotty_auth_token = 'pfconnector:0123456789abcdef0123456789abcdef0123456789abcdef';",
		"var gotty_auth_token = 'a';",
	}
	for _, g := range good {
		if !gottyAuthTokenJS.MatchString(g) {
			t.Errorf("valid auth_token.js refused: %q", g)
		}
	}
	bad := []string{
		"",
		"var gotty_auth_token = '';",
		"var gotty_auth_token = 'x';alert(1);",
		"var gotty_auth_token = 'a'; var gotty_term = 'xterm';",
		"var gotty_auth_token = 'a\\'';",
		"<script>alert(1)</script>",
	}
	for _, b := range bad {
		if gottyAuthTokenJS.MatchString(b) {
			t.Errorf("tampered auth_token.js accepted: %q", b)
		}
	}
}

func TestTerminalStaticPath(t *testing.T) {
	for _, ok := range []string{"js/gotty.js", "css/index.css", "favicon.ico", "icon.svg", "icon_192.png", "manifest.json"} {
		if !terminalStaticPath(ok) {
			t.Errorf("%s should be served from the embedded assets", ok)
		}
	}
	for _, no := range []string{"", "ws", "auth_token.js", "config.js", "js/../index.html", "index.html", "etc/passwd"} {
		if terminalStaticPath(no) {
			t.Errorf("%s must not be served from the embedded assets", no)
		}
	}
}

// The embedded gotty module really carries the assets the index refers to.
func TestGottyStaticAssetsEmbedded(t *testing.T) {
	for _, p := range []string{"/js/gotty.js", "/css/index.css", "/css/xterm.css", "/css/xterm_customize.css", "/favicon.ico", "/icon.svg", "/manifest.json"} {
		rec := httptest.NewRecorder()
		gottyStatic.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, p, nil))
		if rec.Code != http.StatusOK || rec.Body.Len() == 0 {
			t.Errorf("%s: status %d, %d bytes", p, rec.Code, rec.Body.Len())
		}
	}
}
