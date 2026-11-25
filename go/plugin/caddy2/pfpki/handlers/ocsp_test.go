package handlers_test

import (
	"bytes"
	"crypto/x509"
	"encoding/base64"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	xocsp "golang.org/x/crypto/ocsp"
)

// TestOCSP_GoodAndRevoked drives a leaf certificate through the OCSP
// endpoint twice: once while it is valid (expect Good) and once after it has
// been revoked (expect Revoked + the reason we passed in).
//
// The OCSP responder in pfpki only knows how to sign with an RSA CA private
// key, so the test forces an RSA CA + RSA leaf.
func TestOCSP_GoodAndRevoked(t *testing.T) {
	env := testutil.NewEnv(t)

	caKT := certutils.KEY_RSA
	caRow := mustCreateCAFromHTTP(t, env, "ocsp-ca", caKT, 2048, x509.SHA256WithRSA)
	prof := mustCreateProfileFromHTTP(t, env, "ocsp-prof", caRow, caKT, 2048, x509.SHA256WithRSA)

	leafSerial, leafID := mustIssueLeafFromHTTP(t, env, prof, "ocsp-leaf")

	caCert := parsePEMCert(t, caRow.Cert)
	leafCert := loadLeafFromDB(t, env, leafID)

	// Request 1: status Good.
	resp := postOCSP(t, env, leafCert, caCert)
	if resp.Status != xocsp.Good {
		t.Fatalf("first OCSP status = %d, want Good (%d)", resp.Status, xocsp.Good)
	}
	if resp.SerialNumber.String() != leafSerial {
		t.Errorf("OCSP serial=%s, want %s", resp.SerialNumber, leafSerial)
	}

	// Revoke the cert (CRL reason 1 = KeyCompromise: unlike Superseded,
	// it isn't delayed by the profile's revoked_valid_until).
	if err := revokeLeaf(t, env, leafID, xocsp.KeyCompromise); err != nil {
		t.Fatalf("revoke: %v", err)
	}

	// Request 2: status Revoked.
	resp2 := postOCSP(t, env, leafCert, caCert)
	if resp2.Status != xocsp.Revoked {
		t.Fatalf("post-revoke OCSP status = %d, want Revoked (%d)", resp2.Status, xocsp.Revoked)
	}
	if resp2.RevocationReason != xocsp.KeyCompromise {
		t.Errorf("RevocationReason=%d, want %d", resp2.RevocationReason, xocsp.KeyCompromise)
	}

	// A superseded certificate stays good during the profile's
	// revoked_valid_until days (14 by default).
	_, supersededID := mustIssueLeafFromHTTP(t, env, prof, "ocsp-superseded")
	superseded := loadLeafFromDB(t, env, supersededID)
	if err := revokeLeaf(t, env, supersededID, xocsp.Superseded); err != nil {
		t.Fatalf("revoke: %v", err)
	}
	if resp3 := postOCSP(t, env, superseded, caCert); resp3.Status != xocsp.Good {
		t.Fatalf("superseded OCSP status = %d, want Good during the grace period", resp3.Status)
	}
}

// TestOCSP_GET sends the request in the path (RFC 6960 appendix A.1:
// {url}/{url-encoded base64 DER request}), as the OS and browser
// validators do for small requests, with no Content-Type.
func TestOCSP_GET(t *testing.T) {
	env := testutil.NewEnv(t)

	caKT := certutils.KEY_RSA
	caRow := mustCreateCAFromHTTP(t, env, "ocsp-get-ca", caKT, 2048, x509.SHA256WithRSA)
	prof := mustCreateProfileFromHTTP(t, env, "ocsp-get-prof", caRow, caKT, 2048, x509.SHA256WithRSA)
	_, leafID := mustIssueLeafFromHTTP(t, env, prof, "ocsp-get-leaf")
	caCert := parsePEMCert(t, caRow.Cert)
	leafCert := loadLeafFromDB(t, env, leafID)

	reqDER, err := xocsp.CreateRequest(leafCert, caCert, nil)
	if err != nil {
		t.Fatalf("CreateRequest: %v", err)
	}
	b64 := base64.StdEncoding.EncodeToString(reqDER)

	// The base64 as is, and with every byte percent-encoded: both are
	// valid URL encodings, and the second one has the '/', '+' and '='
	// escaped whatever the request looks like. An OCSP URL configured
	// with a trailing slash makes the client send /pki/ocsp//<base64>.
	for name, tail := range map[string]string{"raw": b64, "escaped": percentEncodeAll(b64), "double slash": "/" + b64, "escaped slash": "%2F" + b64} {
		t.Run(name, func(t *testing.T) {
			resp := getOCSP(t, env, "/api/v1/pki/ocsp/"+tail)
			defer resp.Body.Close()
			if resp.StatusCode != http.StatusOK {
				t.Fatalf("GET OCSP -> %d", resp.StatusCode)
			}
			if ct := resp.Header.Get("Content-Type"); ct != "application/ocsp-response" {
				t.Errorf("Content-Type=%q", ct)
			}
			respDER, err := io.ReadAll(resp.Body)
			if err != nil {
				t.Fatal(err)
			}
			parsed, err := xocsp.ParseResponseForCert(respDER, leafCert, caCert)
			if err != nil {
				t.Fatalf("ParseResponse: %v", err)
			}
			if parsed.Status != xocsp.Good {
				t.Fatalf("status=%d, want Good", parsed.Status)
			}

			// RFC 5019 section 6.2 cache headers
			lastModified, err := http.ParseTime(resp.Header.Get("Last-Modified"))
			if err != nil || !lastModified.Equal(parsed.ThisUpdate.Truncate(time.Second)) {
				t.Errorf("Last-Modified=%q, want thisUpdate %s (%v)", resp.Header.Get("Last-Modified"), parsed.ThisUpdate, err)
			}
			expires, err := http.ParseTime(resp.Header.Get("Expires"))
			if err != nil || !expires.Equal(parsed.NextUpdate.Truncate(time.Second)) {
				t.Errorf("Expires=%q, want nextUpdate %s (%v)", resp.Header.Get("Expires"), parsed.NextUpdate, err)
			}
			if etag := resp.Header.Get("ETag"); len(etag) != 42 || !strings.HasPrefix(etag, `"`) {
				t.Errorf("ETag=%q, want a quoted SHA-1", etag)
			}
			cc := resp.Header.Get("Cache-Control")
			if !strings.HasPrefix(cc, "max-age=") || !strings.Contains(cc, "must-revalidate") {
				t.Errorf("Cache-Control=%q", cc)
			}
		})
	}

	// Revoked through GET too.
	if err := revokeLeaf(t, env, leafID, xocsp.KeyCompromise); err != nil {
		t.Fatalf("revoke: %v", err)
	}
	resp := getOCSP(t, env, "/api/v1/pki/ocsp/"+b64)
	respDER, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if parsed, err := xocsp.ParseResponseForCert(respDER, leafCert, caCert); err != nil || parsed.Status != xocsp.Revoked {
		t.Fatalf("post-revoke GET: status=%v err=%v, want Revoked", parsed, err)
	}

	// Not an OCSP request in the path: 400, not a signed answer.
	for _, path := range []string{"/api/v1/pki/ocsp", "/api/v1/pki/ocsp/", "/api/v1/pki/ocsp/not-base64!", "/api/v1/pki/ocsp/" + base64.StdEncoding.EncodeToString([]byte("junk"))} {
		resp := getOCSP(t, env, path)
		resp.Body.Close()
		if resp.StatusCode != http.StatusBadRequest {
			t.Errorf("GET %s -> %d, want 400", path, resp.StatusCode)
		}
	}

	// A POST still needs its Content-Type; a GET answer carries no cache
	// headers on a POST.
	req, _ := http.NewRequest("POST", env.Server.URL+"/api/v1/pki/ocsp/", bytes.NewReader(reqDER))
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("POST without Content-Type -> %d, want 400", resp.StatusCode)
	}
	req.Header.Set("Content-Type", "application/ocsp-request")
	req.Body = io.NopCloser(bytes.NewReader(reqDER))
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK || resp.Header.Get("ETag") != "" {
		t.Errorf("POST -> %d, ETag=%q; want 200 without cache headers", resp.StatusCode, resp.Header.Get("ETag"))
	}
}

func getOCSP(t *testing.T, env *testutil.Env, path string) *http.Response {
	t.Helper()
	resp, err := http.Get(env.Server.URL + path)
	if err != nil {
		t.Fatalf("GET %s: %v", path, err)
	}
	return resp
}

// percentEncodeAll URL-encodes every byte of s.
func percentEncodeAll(s string) string {
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		fmt.Fprintf(&b, "%%%02X", s[i])
	}
	return b.String()
}

// --- HTTP-driven helpers (also exercise the JSON handlers) ---

func mustCreateCAFromHTTP(t *testing.T, env *testutil.Env, cn string, kt types.Type, size int, digest x509.SignatureAlgorithm) models.CA {
	t.Helper()
	body := fmt.Sprintf(`{
		"cn": "%s",
		"mail": "%s@example.test",
		"organisation": "Acme",
		"country": "US",
		"key_type": "%d",
		"key_size": "%d",
		"digest": "%d",
		"key_usage": "32|64",
		"extended_key_usage": "1|2",
		"days": "365"
	}`, cn, cn, int(kt), size, int(digest))

	resp := postJSON(t, env, "/api/v1/pki/cas/", body)
	if resp.StatusCode/100 != 2 {
		t.Fatalf("POST /pki/cas -> %d:\n%s", resp.StatusCode, readBody(t, resp))
	}

	var row models.CA
	if err := env.DB.Where("cn = ?", cn).First(&row).Error; err != nil {
		t.Fatalf("reload CA %q: %v", cn, err)
	}
	return row
}

func mustCreateProfileFromHTTP(t *testing.T, env *testutil.Env, name string, ca models.CA, kt types.Type, size int, digest x509.SignatureAlgorithm) models.Profile {
	t.Helper()
	body := fmt.Sprintf(`{
		"name": "%s",
		"ca_id": "%d",
		"mail": "leaf@example.test",
		"validity": "30",
		"key_type": "%d",
		"key_size": "%d",
		"digest": "%d",
		"key_usage": "1|4",
		"extended_key_usage": "1|2"
	}`, name, ca.ID, int(kt), size, int(digest))

	resp := postJSON(t, env, "/api/v1/pki/profiles/", body)
	if resp.StatusCode/100 != 2 {
		t.Fatalf("POST /pki/profiles -> %d:\n%s", resp.StatusCode, readBody(t, resp))
	}

	var prof models.Profile
	if err := env.DB.Where("name = ?", name).First(&prof).Error; err != nil {
		t.Fatalf("reload Profile %q: %v", name, err)
	}
	return prof
}

func mustIssueLeafFromHTTP(t *testing.T, env *testutil.Env, prof models.Profile, cn string) (serial string, id uint) {
	t.Helper()
	body := fmt.Sprintf(`{
		"cn": "%s",
		"profile_id": "%d",
		"dns_names": "%s.example.test"
	}`, cn, prof.ID, cn)
	resp := postJSON(t, env, "/api/v1/pki/certs/", body)
	if resp.StatusCode/100 != 2 {
		t.Fatalf("POST /pki/certs -> %d:\n%s", resp.StatusCode, readBody(t, resp))
	}

	var cert models.Cert
	if err := env.DB.Where("cn = ?", cn).First(&cert).Error; err != nil {
		t.Fatalf("reload Cert %q: %v", cn, err)
	}
	return cert.SerialNumber, cert.ID
}

// --- raw HTTP / OCSP helpers ---

func postJSON(t *testing.T, env *testutil.Env, path, body string) *http.Response {
	t.Helper()
	req, err := http.NewRequest("POST", env.Server.URL+path, bytes.NewBufferString(body))
	if err != nil {
		t.Fatalf("build request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST %s: %v", path, err)
	}
	return resp
}

func readBody(t *testing.T, resp *http.Response) string {
	t.Helper()
	defer resp.Body.Close()
	b, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read body: %v", err)
	}
	return string(b)
}

func postOCSP(t *testing.T, env *testutil.Env, leaf, issuer *x509.Certificate) *xocsp.Response {
	t.Helper()
	reqDER, err := xocsp.CreateRequest(leaf, issuer, nil)
	if err != nil {
		t.Fatalf("CreateRequest: %v", err)
	}
	req, err := http.NewRequest("POST", env.Server.URL+"/api/v1/pki/ocsp/", bytes.NewReader(reqDER))
	if err != nil {
		t.Fatalf("build OCSP request: %v", err)
	}
	req.Header.Set("Content-Type", "application/ocsp-request")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST OCSP: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("OCSP -> %d: %s", resp.StatusCode, string(body))
	}
	respDER, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read OCSP body: %v", err)
	}
	parsed, err := xocsp.ParseResponse(respDER, issuer)
	if err != nil {
		t.Fatalf("ParseResponse: %v", err)
	}
	return parsed
}

func revokeLeaf(t *testing.T, env *testutil.Env, id uint, reason int) error {
	t.Helper()
	req, err := http.NewRequest("DELETE", env.Server.URL+"/api/v1/pki/cert/"+strconv.FormatUint(uint64(id), 10)+"/"+strconv.Itoa(reason), nil)
	if err != nil {
		return err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("DELETE cert -> %d: %s", resp.StatusCode, string(body))
	}
	return nil
}

func parsePEMCert(t *testing.T, pemStr string) *x509.Certificate {
	t.Helper()
	block, _ := pem.Decode([]byte(pemStr))
	if block == nil {
		t.Fatalf("no PEM in cert: %s", pemStr)
	}
	c, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		t.Fatalf("parse cert: %v", err)
	}
	return c
}

func loadLeafFromDB(t *testing.T, env *testutil.Env, id uint) *x509.Certificate {
	t.Helper()
	var row models.Cert
	if err := env.DB.First(&row, id).Error; err != nil {
		t.Fatalf("load leaf id=%d: %v", id, err)
	}
	return parsePEMCert(t, row.Cert)
}
