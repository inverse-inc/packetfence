package handlers_test

import (
	"bytes"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"testing"

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

	// Revoke the cert (CRL reason 4 = Superseded).
	if err := revokeLeaf(t, env, leafID, xocsp.Superseded); err != nil {
		t.Fatalf("revoke: %v", err)
	}

	// Request 2: status Revoked.
	resp2 := postOCSP(t, env, leafCert, caCert)
	if resp2.Status != xocsp.Revoked {
		t.Fatalf("post-revoke OCSP status = %d, want Revoked (%d)", resp2.Status, xocsp.Revoked)
	}
	if resp2.RevocationReason != xocsp.Superseded {
		t.Errorf("RevocationReason=%d, want %d", resp2.RevocationReason, xocsp.Superseded)
	}
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
