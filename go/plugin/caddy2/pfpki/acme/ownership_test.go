package acme_test

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strings"
	"testing"
	"time"

	jose "github.com/go-jose/go-jose/v4"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/acme"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
)

// readyOrder drives new-order → authz → http-01 for dnsName through the
// mock responder and returns the order URL and finalize URL once the
// order is ready. The mock is installed for the test's lifetime.
func readyOrder(t *testing.T, env *testutil.Env, prof string, c *acmeClient, kid, dnsName string) (orderURL, finalizeURL string) {
	t.Helper()
	mock := startMockHTTP01(t)
	prev := acme.SetHTTP01Client(&http.Client{Transport: mock.rewriteToMock()})
	t.Cleanup(func() { acme.SetHTTP01Client(prev) })

	createURL := newOrderURL(env, prof)
	cr := c.post(t, createURL, c.signed(createURL, modeKID, kid, c.fetchNonce(), map[string]any{
		"identifiers": []map[string]string{{"type": "dns", "value": dnsName}},
	}))
	defer cr.Body.Close()
	if cr.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(cr.Body)
		t.Fatalf("new-order: status=%d body=%s", cr.StatusCode, string(body))
	}
	var ob struct {
		Authorizations []string `json:"authorizations"`
		Finalize       string   `json:"finalize"`
	}
	_ = json.NewDecoder(cr.Body).Decode(&ob)
	orderURL = cr.Header.Get("Location")

	ar := c.post(t, ob.Authorizations[0], c.signed(ob.Authorizations[0], modeKID, kid, c.fetchNonce(), ""))
	defer ar.Body.Close()
	var ab struct {
		Challenges []struct{ URL, Token string }
	}
	_ = json.NewDecoder(ar.Body).Decode(&ab)
	chall := ab.Challenges[0]
	mock.register(chall.Token, chall.Token+"."+mustThumbprint(t, c.jwk))

	chr := c.post(t, chall.URL, c.signed(chall.URL, modeKID, kid, c.fetchNonce(), map[string]any{}))
	chr.Body.Close()
	if chr.StatusCode != http.StatusOK {
		t.Fatalf("challenge: status=%d", chr.StatusCode)
	}
	return orderURL, ob.Finalize
}

// finalizeWith posts csr to finalizeURL and returns the response.
func finalizeWith(t *testing.T, c *acmeClient, kid, finalizeURL string, csr *x509.CertificateRequest, key *ecdsa.PrivateKey) *http.Response {
	t.Helper()
	der, err := x509.CreateCertificateRequest(rand.Reader, csr, key)
	if err != nil {
		t.Fatalf("create CSR: %v", err)
	}
	return c.post(t, finalizeURL, c.signed(finalizeURL, modeKID, kid, c.fetchNonce(), map[string]any{
		"csr": base64.RawURLEncoding.EncodeToString(der),
	}))
}

// issueLeaf runs the whole flow for dnsName and returns the issued leaf,
// its private key and the cert URL.
func issueLeaf(t *testing.T, env *testutil.Env, prof string, c *acmeClient, kid, dnsName string) (*x509.Certificate, *ecdsa.PrivateKey, string) {
	t.Helper()
	_, finalizeURL := readyOrder(t, env, prof, c, kid, dnsName)
	key, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	fr := finalizeWith(t, c, kid, finalizeURL, &x509.CertificateRequest{
		Subject:  pkix.Name{CommonName: dnsName},
		DNSNames: []string{dnsName},
	}, key)
	defer fr.Body.Close()
	if fr.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(fr.Body)
		t.Fatalf("finalize: status=%d body=%s", fr.StatusCode, string(body))
	}
	var fb struct {
		Certificate string `json:"certificate"`
	}
	_ = json.NewDecoder(fr.Body).Decode(&fb)
	cr := c.post(t, fb.Certificate, c.signed(fb.Certificate, modeKID, kid, c.fetchNonce(), ""))
	defer cr.Body.Close()
	if cr.StatusCode != http.StatusOK {
		t.Fatalf("cert download: status=%d", cr.StatusCode)
	}
	chain, _ := io.ReadAll(cr.Body)
	leaf, _ := parseChain(t, chain)
	return leaf, key, fb.Certificate
}

func revokeURL(env *testutil.Env, prof string) string {
	return env.Server.URL + "/api/v1/pki/acme/" + prof + "/revoke-cert"
}

func expectProblem(t *testing.T, resp *http.Response, status int, problemType string) {
	t.Helper()
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != status {
		t.Fatalf("status=%d want %d body=%s", resp.StatusCode, status, string(body))
	}
	if !strings.Contains(string(body), problemType) {
		t.Fatalf("problem type %q missing from body=%s", problemType, string(body))
	}
}

func certStillLive(t *testing.T, env *testutil.Env, leaf *x509.Certificate) bool {
	t.Helper()
	var n int64
	if err := env.DB.Model(&models.Cert{}).Where("serial_number = ?", leaf.SerialNumber.String()).Count(&n).Error; err != nil {
		t.Fatalf("count certs: %v", err)
	}
	return n == 1
}

// TestRevokeCert_ForeignAccountRefused: an account on the same profile
// that did not order the certificate cannot revoke it (RFC 8555 §7.6).
func TestRevokeCert_ForeignAccountRefused(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-own-foreign")
	a, kidA := bootstrapAcmeAccount(t, env, prof)
	leaf, _, _ := issueLeaf(t, env, prof, a, kidA, "victim.example.test")

	b, kidB := bootstrapAcmeAccountAsNewKey(t, env, prof)
	u := revokeURL(env, prof)
	resp := b.post(t, u, b.signed(u, modeKID, kidB, b.fetchNonce(), map[string]any{
		"certificate": base64.RawURLEncoding.EncodeToString(leaf.Raw),
	}))
	expectProblem(t, resp, http.StatusUnauthorized, "unauthorized")
	if !certStillLive(t, env, leaf) {
		t.Fatalf("certificate was revoked by a foreign account")
	}
}

// TestRevokeCert_ByCertificateKey: a JWS signed with the certificate's
// own key (jwk form) may revoke it without an account.
func TestRevokeCert_ByCertificateKey(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-own-certkey")
	a, kidA := bootstrapAcmeAccount(t, env, prof)
	leaf, key, _ := issueLeaf(t, env, prof, a, kidA, "device.example.test")

	certClient := &acmeClient{t: t, env: env, profile: prof, key: key, jwk: &jose.JSONWebKey{Key: key.Public()}}
	u := revokeURL(env, prof)
	resp := certClient.post(t, u, certClient.signed(u, modeJWK, "", certClient.fetchNonce(), map[string]any{
		"certificate": base64.RawURLEncoding.EncodeToString(leaf.Raw),
		"reason":      1,
	}))
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("revoke by cert key: status=%d body=%s", resp.StatusCode, string(body))
	}
	if certStillLive(t, env, leaf) {
		t.Fatalf("certificate still live after revoke by its own key")
	}
}

// TestRevokeCert_WrongKeyRefused: jwk form with a key that is not the
// certificate's key is refused, and a self-made certificate reusing the
// victim's serial does not pass as the issued one.
func TestRevokeCert_WrongKeyRefused(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-own-wrongkey")
	a, kidA := bootstrapAcmeAccount(t, env, prof)
	leaf, _, _ := issueLeaf(t, env, prof, a, kidA, "victim.example.test")

	attacker, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	atk := &acmeClient{t: t, env: env, profile: prof, key: attacker, jwk: &jose.JSONWebKey{Key: attacker.Public()}}
	u := revokeURL(env, prof)

	// Real certificate, wrong key.
	resp := atk.post(t, u, atk.signed(u, modeJWK, "", atk.fetchNonce(), map[string]any{
		"certificate": base64.RawURLEncoding.EncodeToString(leaf.Raw),
	}))
	expectProblem(t, resp, http.StatusUnauthorized, "unauthorized")

	// Forged certificate: victim's serial, attacker's key.
	tmpl := &x509.Certificate{
		SerialNumber: leaf.SerialNumber,
		Subject:      leaf.Subject,
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(time.Hour),
	}
	forgedDER, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &attacker.PublicKey, attacker)
	if err != nil {
		t.Fatalf("forge cert: %v", err)
	}
	resp = atk.post(t, u, atk.signed(u, modeJWK, "", atk.fetchNonce(), map[string]any{
		"certificate": base64.RawURLEncoding.EncodeToString(forgedDER),
	}))
	expectProblem(t, resp, http.StatusNotFound, "malformed")

	if !certStillLive(t, env, leaf) {
		t.Fatalf("certificate was revoked with the wrong key")
	}
}

// TestCertDownload_ForeignAccountRefused: /cert/{serial} is scoped to
// the account the certificate was issued to.
func TestCertDownload_ForeignAccountRefused(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-own-download")
	a, kidA := bootstrapAcmeAccount(t, env, prof)
	_, _, certURL := issueLeaf(t, env, prof, a, kidA, "victim.example.test")

	b, kidB := bootstrapAcmeAccountAsNewKey(t, env, prof)
	resp := b.post(t, certURL, b.signed(certURL, modeKID, kidB, b.fetchNonce(), ""))
	expectProblem(t, resp, http.StatusUnauthorized, "unauthorized")
}

// TestFinalize_BadCSRKeepsOrderReady: a CSR naming anything the order
// did not authorize is refused with badCSR, the order stays ready so
// the client can retry, and a correct CSR then succeeds.
func TestFinalize_BadCSRKeepsOrderReady(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-fin-badcsr")
	c, kid := bootstrapAcmeAccount(t, env, prof)
	orderURL, finalizeURL := readyOrder(t, env, prof, c, kid, "host.lab.example")
	key, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)

	bad := []*x509.CertificateRequest{
		{Subject: pkix.Name{CommonName: "host.lab.example"}, DNSNames: []string{"host.lab.example", "example.bank"}},
		{Subject: pkix.Name{CommonName: "example.bank"}},
		{Subject: pkix.Name{CommonName: "host.lab.example"}, EmailAddresses: []string{"ceo@corp.example"}},
		{Subject: pkix.Name{CommonName: "host.lab.example"}, URIs: []*url.URL{{Scheme: "spiffe", Host: "corp.example", Path: "/admin"}}},
	}
	for i, csr := range bad {
		resp := finalizeWith(t, c, kid, finalizeURL, csr, key)
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		if resp.StatusCode != http.StatusBadRequest || !strings.Contains(string(body), "badCSR") {
			t.Fatalf("bad CSR %d: status=%d body=%s", i, resp.StatusCode, string(body))
		}
		rr := c.post(t, orderURL, c.signed(orderURL, modeKID, kid, c.fetchNonce(), ""))
		var ob struct{ Status string }
		_ = json.NewDecoder(rr.Body).Decode(&ob)
		rr.Body.Close()
		if ob.Status != "ready" {
			t.Fatalf("bad CSR %d: order status=%q, want ready", i, ob.Status)
		}
	}

	// Subject attributes come from the profile, not the CSR: O= in the
	// CSR is accepted but does not reach the certificate.
	good := finalizeWith(t, c, kid, finalizeURL, &x509.CertificateRequest{
		Subject:  pkix.Name{CommonName: "HOST.lab.example", Organization: []string{"Attacker Org"}},
		DNSNames: []string{"host.lab.example"},
	}, key)
	defer good.Body.Close()
	if good.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(good.Body)
		t.Fatalf("good CSR: status=%d body=%s", good.StatusCode, string(body))
	}
	var fb struct{ Status, Certificate string }
	_ = json.NewDecoder(good.Body).Decode(&fb)
	if fb.Status != "valid" {
		t.Fatalf("status=%q want valid", fb.Status)
	}
	var row models.Cert
	if err := env.DB.Where("cn = ?", "HOST.lab.example").First(&row).Error; err != nil {
		t.Fatalf("issued row: %v", err)
	}
	if row.Organisation == "Attacker Org" {
		t.Fatalf("CSR Organization leaked into the issued certificate")
	}

	// A second finalize on the now-valid order is refused.
	again := finalizeWith(t, c, kid, finalizeURL, &x509.CertificateRequest{
		Subject: pkix.Name{CommonName: "host.lab.example"}, DNSNames: []string{"host.lab.example"},
	}, key)
	expectProblem(t, again, http.StatusForbidden, "orderNotReady")
}

// TestChallengeFailure_InvalidatesOrder: a failed http-01 moves the
// challenge, its authz and the order to invalid instead of leaving the
// order pending forever with an untriggerable challenge.
func TestChallengeFailure_InvalidatesOrder(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-chall-fail")
	c, kid := bootstrapAcmeAccount(t, env, prof)

	mock := startMockHTTP01(t) // nothing registered → 404 for every token
	prev := acme.SetHTTP01Client(&http.Client{Transport: mock.rewriteToMock()})
	t.Cleanup(func() { acme.SetHTTP01Client(prev) })

	createURL := newOrderURL(env, prof)
	cr := c.post(t, createURL, c.signed(createURL, modeKID, kid, c.fetchNonce(), map[string]any{
		"identifiers": []map[string]string{{"type": "dns", "value": "nobody.example.test"}},
	}))
	var ob struct {
		Authorizations []string `json:"authorizations"`
	}
	_ = json.NewDecoder(cr.Body).Decode(&ob)
	cr.Body.Close()
	orderURL := cr.Header.Get("Location")

	ar := c.post(t, ob.Authorizations[0], c.signed(ob.Authorizations[0], modeKID, kid, c.fetchNonce(), ""))
	var ab struct {
		Challenges []struct{ URL string }
	}
	_ = json.NewDecoder(ar.Body).Decode(&ab)
	ar.Body.Close()

	chr := c.post(t, ab.Challenges[0].URL, c.signed(ab.Challenges[0].URL, modeKID, kid, c.fetchNonce(), map[string]any{}))
	var cb struct{ Status string }
	_ = json.NewDecoder(chr.Body).Decode(&cb)
	chr.Body.Close()
	if cb.Status != "invalid" {
		t.Fatalf("challenge status=%q want invalid", cb.Status)
	}

	rr := c.post(t, orderURL, c.signed(orderURL, modeKID, kid, c.fetchNonce(), ""))
	var order struct {
		Status string `json:"status"`
		Error  any    `json:"error"`
	}
	_ = json.NewDecoder(rr.Body).Decode(&order)
	rr.Body.Close()
	if order.Status != "invalid" || order.Error == nil {
		t.Fatalf("order status=%q error=%v, want invalid with a problem", order.Status, order.Error)
	}
}

// TestNewOrder_RejectsHostileIdentifiers: values shaped to turn the
// http-01 fetch into an SSRF are refused at order time, as is a
// permanent-identifier on a profile without an attestation format.
func TestNewOrder_RejectsHostileIdentifiers(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-order-hostile")
	c, kid := bootstrapAcmeAccount(t, env, prof)
	if err := env.DB.Model(&models.Profile{}).Where("name = ?", prof).
		Update("acme_allowed_identifiers", "dns,ip,permanent-identifier").Error; err != nil {
		t.Fatal(err)
	}
	createURL := newOrderURL(env, prof)
	for _, ident := range []map[string]string{
		{"type": "dns", "value": "127.0.0.1:22225/api/v1/pki/checkrenewal?x="},
		{"type": "dns", "value": "localhost/../../"},
		{"type": "ip", "value": "127.0.0.1"},
		{"type": "ip", "value": "169.254.169.254"},
		{"type": "permanent-identifier", "value": "C02XY1234567"},
	} {
		resp := c.post(t, createURL, c.signed(createURL, modeKID, kid, c.fetchNonce(), map[string]any{
			"identifiers": []map[string]string{ident},
		}))
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		if resp.StatusCode != http.StatusBadRequest || !strings.Contains(string(body), "rejectedIdentifier") {
			t.Fatalf("%v: status=%d body=%s", ident, resp.StatusCode, string(body))
		}
	}
	var n int64
	_ = env.DB.Model(&models.AcmeOrder{}).Count(&n).Error
	if n != 0 {
		t.Fatalf("%d orders were persisted for rejected identifiers", n)
	}
}
