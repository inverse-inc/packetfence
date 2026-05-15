package acme_test

import (
	"crypto"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	jose "github.com/go-jose/go-jose/v4"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/acme"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
)

// mockHTTP01Responder stands up a tiny HTTP server that answers the
// device-side .well-known/acme-challenge/{token} requests with the
// expected `token.thumbprint` body. The ACME server's http-01
// validator GETs the responder during challenge validation; here we
// pre-register the token→body mapping the validator should see.
//
// We swap the validator's http.Client to a transport that rewrites
// the request URL host to the mock's host, so the order's "fake"
// identifier (radius.example.test) routes to the test responder
// without DNS / hosts-file shenanigans.
type mockHTTP01Responder struct {
	server   *httptest.Server
	bodies   map[string]string
}

func startMockHTTP01(t *testing.T) *mockHTTP01Responder {
	t.Helper()
	m := &mockHTTP01Responder{bodies: map[string]string{}}
	m.server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// /.well-known/acme-challenge/<token>
		prefix := "/.well-known/acme-challenge/"
		if !strings.HasPrefix(r.URL.Path, prefix) {
			http.NotFound(w, r)
			return
		}
		token := r.URL.Path[len(prefix):]
		body, ok := m.bodies[token]
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/plain")
		_, _ = w.Write([]byte(body))
	}))
	t.Cleanup(m.server.Close)
	return m
}

// register records the key authorization the mock will return for a
// given challenge token.
func (m *mockHTTP01Responder) register(token, keyAuth string) {
	m.bodies[token] = keyAuth
}

// rewriteToMock returns an http.RoundTripper that redirects every
// request the ACME server makes for http://<anything>/.well-known/...
// to the mock responder. This lets the validator make a real fetch
// against a synthetic identifier.
func (m *mockHTTP01Responder) rewriteToMock() http.RoundTripper {
	mockURL, _ := url.Parse(m.server.URL)
	return roundTripFunc(func(req *http.Request) (*http.Response, error) {
		req = req.Clone(req.Context())
		req.URL.Host = mockURL.Host
		req.URL.Scheme = mockURL.Scheme
		req.Host = mockURL.Host
		return http.DefaultTransport.RoundTrip(req)
	})
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func TestACME_EndToEndIssuance(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-e2e")
	client, kid := bootstrapAcmeAccount(t, env, prof)

	// --- 1. Stand up the mock HTTP-01 responder and divert the
	// validator's transport to it.
	mock := startMockHTTP01(t)
	prev := acme.SetHTTP01Client(&http.Client{Transport: mock.rewriteToMock()})
	t.Cleanup(func() { acme.SetHTTP01Client(prev) })

	// --- 2. new-order.
	createURL := newOrderURL(env, prof)
	createJWS := client.signed(createURL, modeKID, kid, client.fetchNonce(), map[string]any{
		"identifiers": []map[string]string{
			{"type": "dns", "value": "radius.example.test"},
		},
	})
	cr := client.post(t, createURL, createJWS)
	defer cr.Body.Close()
	if cr.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(cr.Body)
		t.Fatalf("new-order: status=%d body=%s", cr.StatusCode, string(body))
	}
	var orderBody struct {
		Status         string   `json:"status"`
		Authorizations []string `json:"authorizations"`
		Finalize       string   `json:"finalize"`
	}
	if err := json.NewDecoder(cr.Body).Decode(&orderBody); err != nil {
		t.Fatalf("decode order: %v", err)
	}
	orderURLValue := cr.Header.Get("Location")

	// --- 3. Fetch the authz to get the challenge URL + token.
	authzJWS := client.signed(orderBody.Authorizations[0], modeKID, kid, client.fetchNonce(), "")
	authzResp := client.post(t, orderBody.Authorizations[0], authzJWS)
	defer authzResp.Body.Close()
	var authzBody struct {
		Challenges []struct {
			Type, URL, Status, Token string
		}
	}
	if err := json.NewDecoder(authzResp.Body).Decode(&authzBody); err != nil {
		t.Fatalf("decode authz: %v", err)
	}
	if len(authzBody.Challenges) != 1 {
		t.Fatalf("got %d challenges, want 1", len(authzBody.Challenges))
	}
	chall := authzBody.Challenges[0]

	// --- 4. Pre-place the key authorization on the mock responder.
	thumb := mustThumbprint(t, client.jwk)
	mock.register(chall.Token, chall.Token+"."+thumb)

	// --- 5. POST the challenge URL to ask the server to validate.
	chJWS := client.signed(chall.URL, modeKID, kid, client.fetchNonce(), map[string]any{})
	chResp := client.post(t, chall.URL, chJWS)
	defer chResp.Body.Close()
	if chResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(chResp.Body)
		t.Fatalf("challenge: status=%d body=%s", chResp.StatusCode, string(body))
	}

	// --- 6. Read the order back; should be ready.
	readJWS := client.signed(orderURLValue, modeKID, kid, client.fetchNonce(), "")
	readResp := client.post(t, orderURLValue, readJWS)
	readResp.Body.Close()
	var afterChall struct{ Status string }
	{
		// Re-fetch (POST-as-GET needs a fresh nonce each call).
		readJWS2 := client.signed(orderURLValue, modeKID, kid, client.fetchNonce(), "")
		readResp2 := client.post(t, orderURLValue, readJWS2)
		defer readResp2.Body.Close()
		_ = json.NewDecoder(readResp2.Body).Decode(&afterChall)
	}
	if afterChall.Status != "ready" {
		t.Fatalf("order status after challenge=%q want ready", afterChall.Status)
	}

	// --- 7. Build a CSR for the identifier + finalize.
	csrKey, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	csrDER, err := x509.CreateCertificateRequest(rand.Reader, &x509.CertificateRequest{
		Subject:  pkix.Name{CommonName: "radius.example.test"},
		DNSNames: []string{"radius.example.test"},
	}, csrKey)
	if err != nil {
		t.Fatalf("create CSR: %v", err)
	}
	finalizeJWS := client.signed(orderBody.Finalize, modeKID, kid, client.fetchNonce(), map[string]any{
		"csr": base64.RawURLEncoding.EncodeToString(csrDER),
	})
	finResp := client.post(t, orderBody.Finalize, finalizeJWS)
	defer finResp.Body.Close()
	if finResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(finResp.Body)
		t.Fatalf("finalize: status=%d body=%s", finResp.StatusCode, string(body))
	}
	var finBody struct {
		Status      string `json:"status"`
		Certificate string `json:"certificate"`
	}
	if err := json.NewDecoder(finResp.Body).Decode(&finBody); err != nil {
		t.Fatalf("decode finalize: %v", err)
	}
	if finBody.Status != "valid" {
		t.Fatalf("order status after finalize=%q want valid", finBody.Status)
	}
	if finBody.Certificate == "" {
		t.Fatalf("finalize did not return a certificate URL")
	}

	// --- 8. Download the cert chain and verify it chains to the CA.
	certJWS := client.signed(finBody.Certificate, modeKID, kid, client.fetchNonce(), "")
	certResp := client.post(t, finBody.Certificate, certJWS)
	defer certResp.Body.Close()
	if certResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(certResp.Body)
		t.Fatalf("cert: status=%d body=%s", certResp.StatusCode, string(body))
	}
	if ct := certResp.Header.Get("Content-Type"); ct != "application/pem-certificate-chain" {
		t.Errorf("Content-Type=%q want application/pem-certificate-chain", ct)
	}
	chainPEM, _ := io.ReadAll(certResp.Body)
	leaf, ca := parseChain(t, chainPEM)
	if leaf.Subject.CommonName != "radius.example.test" {
		t.Errorf("leaf CN=%q want radius.example.test", leaf.Subject.CommonName)
	}
	roots := x509.NewCertPool()
	roots.AddCert(ca)
	if _, err := leaf.Verify(x509.VerifyOptions{Roots: roots, KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageAny}}); err != nil {
		t.Fatalf("verify leaf against CA: %v", err)
	}

	// --- 9. Revoke the cert via /revoke-cert and confirm the row
	// moved to pki_revoked_certs.
	revokeURL := env.Server.URL + "/api/v1/pki/acme/" + prof + "/revoke-cert"
	revokeJWS := client.signed(revokeURL, modeKID, kid, client.fetchNonce(), map[string]any{
		"certificate": base64.RawURLEncoding.EncodeToString(leaf.Raw),
		"reason":      4, // superseded
	})
	revokeResp := client.post(t, revokeURL, revokeJWS)
	defer revokeResp.Body.Close()
	if revokeResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(revokeResp.Body)
		t.Fatalf("revoke: status=%d body=%s", revokeResp.StatusCode, string(body))
	}
	var rev models.RevokedCert
	if err := env.DB.Where("serial_number = ?", leaf.SerialNumber.String()).First(&rev).Error; err != nil {
		t.Fatalf("revoked row not found: %v", err)
	}
	if rev.CRLReason != 4 {
		t.Errorf("revoked.CRLReason=%d want 4", rev.CRLReason)
	}
}

// parseChain splits a leaf+CA PEM bundle into the two parsed
// certificates.
func parseChain(t *testing.T, chain []byte) (leaf, ca *x509.Certificate) {
	t.Helper()
	rest := chain
	var certs []*x509.Certificate
	for {
		block, remaining := pem.Decode(rest)
		if block == nil {
			break
		}
		if block.Type == "CERTIFICATE" {
			c, err := x509.ParseCertificate(block.Bytes)
			if err != nil {
				t.Fatalf("parse cert: %v", err)
			}
			certs = append(certs, c)
		}
		rest = remaining
	}
	if len(certs) < 2 {
		t.Fatalf("got %d certs in chain, want at least 2", len(certs))
	}
	return certs[0], certs[1]
}

// Keep `crypto` and `jose` import references live; they're used
// transitively by the JWS helpers from jws_test.go.
var (
	_ = jose.ES256
	_ = crypto.SHA256
)
