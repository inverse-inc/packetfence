package est_test

import (
	"bytes"
	"crypto"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"io"
	"mime"
	"mime/multipart"
	"net"
	"net/http"
	"net/url"
	"strings"
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/smallstep/pkcs7"
)

const (
	estUser     = "device"
	estPassword = "s3cret"
)

func mustEnableESTProfile(t *testing.T, env *testutil.Env, name string) {
	t.Helper()

	kt := certutils.KEY_ECDSA
	keyUsage := "32|64"
	extKeyUsage := "1|2"
	ca := models.CA{
		Cn:               "est-test-ca",
		KeyType:          &kt,
		KeySize:          256,
		Digest:           x509.ECDSAWithSHA256,
		KeyUsage:         &keyUsage,
		ExtendedKeyUsage: &extKeyUsage,
		Days:             365,
		DB:               env.DB,
		Ctx:              env.Ctx,
	}
	if _, err := ca.New(); err != nil {
		t.Fatalf("CA.New: %v", err)
	}
	var caRow models.CA
	if err := env.DB.Where("cn = ?", "est-test-ca").First(&caRow).Error; err != nil {
		t.Fatalf("reload CA: %v", err)
	}

	leafKU := "1|4"
	leafEKU := "2"
	prof := models.Profile{
		Name:             name,
		CaID:             caRow.ID,
		Validity:         90,
		KeyType:          &kt,
		KeySize:          256,
		Digest:           x509.ECDSAWithSHA256,
		KeyUsage:         &leafKU,
		ExtendedKeyUsage: &leafEKU,
		Organisation:     "Inverse",
		DB:               env.DB,
		Ctx:              env.Ctx,
	}
	if _, err := prof.New(); err != nil {
		t.Fatalf("Profile.New: %v", err)
	}
	if err := env.DB.Model(&models.Profile{}).Where("name = ?", name).Updates(map[string]interface{}{
		"est_enabled":  1,
		"est_username": estUser,
		"est_password": estPassword,
	}).Error; err != nil {
		t.Fatalf("enable EST: %v", err)
	}
}

func newCSR(t *testing.T, cn string, dns ...string) (string, crypto.Signer) {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	return signCSR(t, key, &x509.CertificateRequest{
		Subject:  pkix.Name{CommonName: cn, Organization: []string{"Ignored"}},
		DNSNames: dns,
	}), key
}

// signCSR returns the base64 CSR of tmpl signed with key.
func signCSR(t *testing.T, key crypto.Signer, tmpl *x509.CertificateRequest) string {
	t.Helper()
	der, err := x509.CreateCertificateRequest(rand.Reader, tmpl, key)
	if err != nil {
		t.Fatal(err)
	}
	return base64.StdEncoding.EncodeToString(der)
}

func do(t *testing.T, method, url, body string, auth bool, password string) *http.Response {
	t.Helper()
	req, err := http.NewRequest(method, url, strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	if body != "" {
		req.Header.Set("Content-Type", "application/pkcs10")
		req.Header.Set("Content-Transfer-Encoding", "base64")
	}
	if auth {
		req.SetBasicAuth(estUser, password)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	return resp
}

func readCerts(t *testing.T, r io.Reader) []*x509.Certificate {
	t.Helper()
	b, err := io.ReadAll(r)
	if err != nil {
		t.Fatal(err)
	}
	der, err := base64.StdEncoding.DecodeString(strings.Join(strings.Fields(string(b)), ""))
	if err != nil {
		t.Fatalf("base64: %v (%q)", err, b)
	}
	p7, err := pkcs7.Parse(der)
	if err != nil {
		t.Fatalf("pkcs7: %v", err)
	}
	return p7.Certificates
}

func wantStatus(t *testing.T, resp *http.Response, want int) {
	t.Helper()
	if resp.StatusCode != want {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("%s %s: status %d, want %d (%s)", resp.Request.Method, resp.Request.URL.Path, resp.StatusCode, want, body)
	}
}

func TestEST(t *testing.T) {
	env := testutil.NewEnv(t)
	mustEnableESTProfile(t, env, "est-prof")
	base := env.Server.URL + "/api/v1/.well-known/est/est-prof"

	// cacerts, with and without the label, and from the /pki/est mount.
	var ca *x509.Certificate
	for _, url := range []string{base + "/cacerts", env.Server.URL + "/api/v1/.well-known/est/cacerts", env.Server.URL + "/api/v1/pki/est/est-prof/cacerts"} {
		resp := do(t, http.MethodGet, url, "", false, "")
		wantStatus(t, resp, http.StatusOK)
		if ct := resp.Header.Get("Content-Type"); ct != "application/pkcs7-mime" {
			t.Errorf("cacerts Content-Type %q", ct)
		}
		certs := readCerts(t, resp.Body)
		if len(certs) != 1 || certs[0].Subject.CommonName != "est-test-ca" {
			t.Fatalf("cacerts returned %v", certs)
		}
		ca = certs[0]
	}

	wantStatus(t, do(t, http.MethodGet, base+"/csrattrs", "", false, ""), http.StatusNoContent)
	wantStatus(t, do(t, http.MethodGet, env.Server.URL+"/api/v1/.well-known/est/nope/cacerts", "", false, ""), http.StatusNotFound)

	csr, key := newCSR(t, "device1.example.test", "device1.example.test")

	// Authentication.
	resp := do(t, http.MethodPost, base+"/simpleenroll", csr, false, "")
	wantStatus(t, resp, http.StatusUnauthorized)
	if !strings.HasPrefix(resp.Header.Get("WWW-Authenticate"), "Basic ") {
		t.Errorf("missing WWW-Authenticate, got %q", resp.Header.Get("WWW-Authenticate"))
	}
	wantStatus(t, do(t, http.MethodPost, base+"/simpleenroll", csr, true, "wrong"), http.StatusUnauthorized)
	wantStatus(t, do(t, http.MethodPost, base+"/simpleenroll", "not a csr", true, estPassword), http.StatusBadRequest)

	// simpleenroll.
	resp = do(t, http.MethodPost, base+"/simpleenroll", csr, true, estPassword)
	wantStatus(t, resp, http.StatusOK)
	if ct := resp.Header.Get("Content-Type"); !strings.Contains(ct, "smime-type=certs-only") {
		t.Errorf("simpleenroll Content-Type %q", ct)
	}
	certs := readCerts(t, resp.Body)
	if len(certs) != 1 {
		t.Fatalf("simpleenroll returned %d certs", len(certs))
	}
	leaf := certs[0]
	if err := leaf.CheckSignatureFrom(ca); err != nil {
		t.Fatalf("leaf not signed by the CA: %v", err)
	}
	if leaf.Subject.CommonName != "device1.example.test" || len(leaf.Subject.Organization) != 1 || leaf.Subject.Organization[0] != "Inverse" {
		t.Errorf("leaf subject %v: CN from the CSR, O from the profile expected", leaf.Subject)
	}
	if len(leaf.DNSNames) != 1 || leaf.DNSNames[0] != "device1.example.test" {
		t.Errorf("leaf DNS names %v", leaf.DNSNames)
	}
	if !leaf.PublicKey.(*ecdsa.PublicKey).Equal(key.Public()) {
		t.Errorf("leaf public key differs from the CSR's")
	}
	var row models.Cert
	if err := env.DB.Where("serial_number = ?", leaf.SerialNumber.String()).First(&row).Error; err != nil {
		t.Fatalf("issued cert not stored: %v", err)
	}

	// A second simpleenroll for the same CN is refused by the duplicate-CN policy.
	csr2, _ := newCSR(t, "device1.example.test")
	wantStatus(t, do(t, http.MethodPost, base+"/simpleenroll", csr2, true, estPassword), http.StatusForbidden)

	// simplereenroll with another key doesn't replace it: only the
	// holder of the certificate key may renew it.
	wantStatus(t, do(t, http.MethodPost, base+"/simplereenroll", csr2, true, estPassword), http.StatusForbidden)
	var live int64
	env.DB.Model(&models.Cert{}).Where("cn = ?", "device1.example.test").Count(&live)
	if live != 1 {
		t.Fatalf("%d live certificates for the CN after a refused re-enrollment, want 1", live)
	}

	// simplereenroll with the certificate key replaces it.
	resp = do(t, http.MethodPost, base+"/simplereenroll", signCSR(t, key, &x509.CertificateRequest{
		Subject: pkix.Name{CommonName: "device1.example.test"},
	}), true, estPassword)
	wantStatus(t, resp, http.StatusOK)
	renewed := readCerts(t, resp.Body)[0]
	if renewed.SerialNumber.Cmp(leaf.SerialNumber) == 0 {
		t.Fatalf("re-enrollment reused serial %s", leaf.SerialNumber)
	}
	if !renewed.PublicKey.(*ecdsa.PublicKey).Equal(key.Public()) {
		t.Errorf("renewed public key differs from the CSR's")
	}
	var revoked models.RevokedCert
	if err := env.DB.Where("serial_number = ?", leaf.SerialNumber.String()).First(&revoked).Error; err != nil {
		t.Errorf("previous certificate not revoked: %v", err)
	}
	env.DB.Model(&models.Cert{}).Where("cn = ?", "device1.example.test").Count(&live)
	if live != 1 {
		t.Errorf("%d live certificates for the CN after re-enrollment, want 1", live)
	}

	// simplereenroll without an existing certificate is refused.
	csr3, _ := newCSR(t, "unknown.example.test")
	wantStatus(t, do(t, http.MethodPost, base+"/simplereenroll", csr3, true, estPassword), http.StatusForbidden)

	// serverkeygen returns the generated key and its certificate.
	csr4, _ := newCSR(t, "device2.example.test", "device2.example.test")
	resp = do(t, http.MethodPost, base+"/serverkeygen", csr4, true, estPassword)
	wantStatus(t, resp, http.StatusOK)
	mediaType, params, err := mime.ParseMediaType(resp.Header.Get("Content-Type"))
	if err != nil || mediaType != "multipart/mixed" {
		t.Fatalf("serverkeygen Content-Type %q", resp.Header.Get("Content-Type"))
	}
	mr := multipart.NewReader(resp.Body, params["boundary"])
	var genKey crypto.Signer
	var genCert *x509.Certificate
	for {
		part, err := mr.NextPart()
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatal(err)
		}
		switch ct := part.Header.Get("Content-Type"); {
		case ct == "application/pkcs8":
			b, _ := io.ReadAll(part)
			der, err := base64.StdEncoding.DecodeString(strings.Join(strings.Fields(string(b)), ""))
			if err != nil {
				t.Fatal(err)
			}
			k, err := x509.ParsePKCS8PrivateKey(der)
			if err != nil {
				t.Fatalf("pkcs8: %v", err)
			}
			genKey = k.(crypto.Signer)
		case strings.HasPrefix(ct, "application/pkcs7-mime"):
			genCert = readCerts(t, part)[0]
		default:
			t.Errorf("unexpected part %q", ct)
		}
	}
	if genKey == nil || genCert == nil {
		t.Fatalf("serverkeygen: key=%v cert=%v", genKey != nil, genCert != nil)
	}
	if genCert.Subject.CommonName != "device2.example.test" || len(genCert.DNSNames) != 1 {
		t.Errorf("serverkeygen cert subject %v SANs %v", genCert.Subject, genCert.DNSNames)
	}
	if !bytes.Equal(mustMarshalPub(t, genKey.Public()), mustMarshalPub(t, genCert.PublicKey)) {
		t.Errorf("serverkeygen key does not match the certificate")
	}

	// A device may only name itself: SANs other than its CN are refused,
	// whatever the operation.
	other, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	for name, tmpl := range map[string]*x509.CertificateRequest{
		"foreign DNS name": {Subject: pkix.Name{CommonName: "device3.example.test"}, DNSNames: []string{"device3.example.test", "www.bank.test"}},
		"foreign email":    {Subject: pkix.Name{CommonName: "device3.example.test"}, EmailAddresses: []string{"admin@bank.test"}},
		"IP address":       {Subject: pkix.Name{CommonName: "device3.example.test"}, IPAddresses: []net.IP{net.ParseIP("10.0.0.1")}},
		"URI":              {Subject: pkix.Name{CommonName: "device3.example.test"}, URIs: []*url.URL{{Scheme: "https", Host: "bank.test"}}},
	} {
		for _, op := range []string{"/simpleenroll", "/serverkeygen"} {
			resp := do(t, http.MethodPost, base+op, signCSR(t, other, tmpl), true, estPassword)
			if resp.StatusCode != http.StatusForbidden {
				t.Errorf("%s with %s: status %d, want 403", op, name, resp.StatusCode)
			}
		}
	}
	resp = do(t, http.MethodPost, base+"/simpleenroll", signCSR(t, other, &x509.CertificateRequest{
		Subject: pkix.Name{CommonName: "Device3.example.test"}, DNSNames: []string{"device3.example.test"},
	}), true, estPassword)
	wantStatus(t, resp, http.StatusOK)

	// Disabling EST on the profile closes every endpoint.
	env.DB.Model(&models.Profile{}).Where("name = ?", "est-prof").Update("est_enabled", 0)
	wantStatus(t, do(t, http.MethodGet, base+"/cacerts", "", false, ""), http.StatusNotFound)
}

// An EST-enabled profile without a password refuses every enrollment.
func TestESTRequiresPassword(t *testing.T) {
	env := testutil.NewEnv(t)
	mustEnableESTProfile(t, env, "est-nopass")
	env.DB.Model(&models.Profile{}).Where("name = ?", "est-nopass").Update("est_password", "")
	csr, _ := newCSR(t, "device.example.test")
	req, _ := http.NewRequest(http.MethodPost, env.Server.URL+"/api/v1/.well-known/est/est-nopass/simpleenroll", strings.NewReader(csr))
	req.SetBasicAuth(estUser, "")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	wantStatus(t, resp, http.StatusUnauthorized)
}

func mustMarshalPub(t *testing.T, pub crypto.PublicKey) []byte {
	t.Helper()
	b, err := x509.MarshalPKIXPublicKey(pub)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

// Requests the reverse proxy received over plain HTTP are refused.
func TestESTRequiresHTTPS(t *testing.T) {
	env := testutil.NewEnv(t)
	mustEnableESTProfile(t, env, "est-https")
	base := env.Server.URL + "/api/v1/.well-known/est/est-https"
	csr, _ := newCSR(t, "device.example.test")
	for _, protos := range [][]string{{"http"}, {"https", "http"}, {"https, http"}} {
		req, _ := http.NewRequest(http.MethodPost, base+"/simpleenroll", strings.NewReader(csr))
		req.SetBasicAuth(estUser, estPassword)
		for _, p := range protos {
			req.Header.Add("X-Forwarded-Proto", p)
		}
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		resp.Body.Close()
		if resp.StatusCode != http.StatusForbidden {
			t.Errorf("X-Forwarded-Proto %v: status %d, want 403", protos, resp.StatusCode)
		}
	}
	req, _ := http.NewRequest(http.MethodPost, base+"/simpleenroll", strings.NewReader(csr))
	req.SetBasicAuth(estUser, estPassword)
	req.Header.Set("X-Forwarded-Proto", "https")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	wantStatus(t, resp, http.StatusOK)
}
