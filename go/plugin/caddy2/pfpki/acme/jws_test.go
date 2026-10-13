package acme_test

import (
	"bytes"
	"crypto"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"testing"

	jose "github.com/go-jose/go-jose/v4"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
)

// acmeClient is a tiny harness around go-jose that signs ACME-shaped
// JWSes against the test httptest.Server. Real device-side libraries
// (acmez, certbot) do roughly the same work; we model just enough to
// drive the endpoints.
type acmeClient struct {
	t       *testing.T
	env     *testutil.Env
	profile string
	key     *ecdsa.PrivateKey
	jwk     *jose.JSONWebKey
	signer  jose.Signer
}

func newACMEClient(t *testing.T, env *testutil.Env, profile string) *acmeClient {
	t.Helper()
	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("ecdsa keygen: %v", err)
	}
	// Don't set Algorithm on the public JWK — go-jose's EmbedJWK omits
	// `alg` from the embedded JWK in the outer protected header, so
	// matching that absence here keeps the EAB inner payload byte-
	// comparable to whatever the server actually parses.
	pub := &jose.JSONWebKey{Key: priv.Public()}
	signer, err := jose.NewSigner(
		jose.SigningKey{Algorithm: jose.ES256, Key: priv},
		(&jose.SignerOptions{}).WithType("JWT"),
	)
	if err != nil {
		t.Fatalf("jose.NewSigner: %v", err)
	}
	return &acmeClient{t: t, env: env, profile: profile, key: priv, jwk: pub, signer: signer}
}

// fetchNonce grabs a fresh Replay-Nonce from /new-nonce. RFC 8555
// clients keep one of these in flight at all times; the test does it
// per-request for simplicity.
func (c *acmeClient) fetchNonce() string {
	c.t.Helper()
	resp, err := http.Head(c.env.Server.URL + "/api/v1/pki/acme/" + c.profile + "/new-nonce")
	if err != nil {
		c.t.Fatalf("HEAD /new-nonce: %v", err)
	}
	defer resp.Body.Close()
	n := resp.Header.Get("Replay-Nonce")
	if n == "" {
		c.t.Fatalf("no Replay-Nonce header")
	}
	return n
}

// signed builds the flattened-JSON ACME JWS for an arbitrary payload,
// targeted at url. mode=jwk embeds the public key (new-account); kid
// uses the supplied account URL.
type sigMode int

const (
	modeJWK sigMode = iota + 1
	modeKID
)

func (c *acmeClient) signed(url string, mode sigMode, kid string, nonce string, payload any) []byte {
	c.t.Helper()
	body, err := json.Marshal(payload)
	if err != nil {
		c.t.Fatalf("marshal payload: %v", err)
	}
	// Build a fresh signer per request: ACME requires `nonce` + `url`
	// in the protected header, and jose's signer takes them via
	// SignerOptions.ExtraHeaders.
	opts := &jose.SignerOptions{
		ExtraHeaders: map[jose.HeaderKey]any{
			"nonce": nonce,
			"url":   url,
		},
	}
	switch mode {
	case modeJWK:
		opts.EmbedJWK = true
	case modeKID:
		opts.WithHeader("kid", kid)
	}
	signer, err := jose.NewSigner(jose.SigningKey{Algorithm: jose.ES256, Key: c.key}, opts)
	if err != nil {
		c.t.Fatalf("signer: %v", err)
	}
	sig, err := signer.Sign(body)
	if err != nil {
		c.t.Fatalf("sign: %v", err)
	}
	return []byte(sig.FullSerialize())
}

func (c *acmeClient) post(t *testing.T, url string, body []byte) *http.Response {
	t.Helper()
	req, _ := http.NewRequest("POST", url, bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/jose+json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST %s: %v", url, err)
	}
	return resp
}

// --- helpers shared with the smoke-test file ---

func newAccountURL(env *testutil.Env, profile string) string {
	return env.Server.URL + "/api/v1/pki/acme/" + profile + "/new-account"
}

func TestNewAccount_Happy(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-acct")
	// EAB-required is the default; turn it off for the happy path —
	// we cover EAB separately below.
	if err := env.DB.Model(&models.Profile{}).Where("name = ?", prof).
		Update("acme_eab_required", 0).Error; err != nil {
		t.Fatalf("disable EAB: %v", err)
	}

	c := newACMEClient(t, env, prof)
	url := newAccountURL(env, prof)
	nonce := c.fetchNonce()
	jws := c.signed(url, modeJWK, "", nonce, map[string]any{"termsOfServiceAgreed": true})

	resp := c.post(t, url, jws)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("status=%d want 201; body=%s", resp.StatusCode, string(body))
	}
	if loc := resp.Header.Get("Location"); loc == "" {
		t.Errorf("missing Location header")
	}
	if rn := resp.Header.Get("Replay-Nonce"); rn == "" {
		t.Errorf("missing Replay-Nonce header")
	}

	// Persisted row should match.
	thumb := mustThumbprint(t, c.jwk)
	var row models.AcmeAccount
	if err := env.DB.Where("key_thumbprint = ?", thumb).First(&row).Error; err != nil {
		t.Fatalf("account row not found: %v", err)
	}
	if row.Status != "valid" {
		t.Errorf("status=%q want valid", row.Status)
	}
	if row.KeyID == "" {
		t.Errorf("KeyID was not persisted")
	}
}

func TestNewAccount_ExistingReturns200(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-acct-dup")
	_ = env.DB.Model(&models.Profile{}).Where("name = ?", prof).
		Update("acme_eab_required", 0)

	c := newACMEClient(t, env, prof)
	url := newAccountURL(env, prof)

	// First call: creates.
	jws := c.signed(url, modeJWK, "", c.fetchNonce(), map[string]any{})
	r1 := c.post(t, url, jws)
	r1.Body.Close()
	if r1.StatusCode != http.StatusCreated {
		t.Fatalf("first call status=%d want 201", r1.StatusCode)
	}

	// Second call with the same key: matches the existing row.
	jws2 := c.signed(url, modeJWK, "", c.fetchNonce(), map[string]any{})
	r2 := c.post(t, url, jws2)
	defer r2.Body.Close()
	if r2.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(r2.Body)
		t.Fatalf("second call status=%d want 200; body=%s", r2.StatusCode, string(body))
	}
	if r1.Header.Get("Location") != r2.Header.Get("Location") {
		t.Errorf("Location differs across calls: %q vs %q",
			r1.Header.Get("Location"), r2.Header.Get("Location"))
	}
}

func TestNewAccount_OnlyReturnExistingMissing(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-acct-only")
	_ = env.DB.Model(&models.Profile{}).Where("name = ?", prof).
		Update("acme_eab_required", 0)

	c := newACMEClient(t, env, prof)
	url := newAccountURL(env, prof)
	jws := c.signed(url, modeJWK, "", c.fetchNonce(), map[string]any{
		"onlyReturnExisting": true,
	})
	resp := c.post(t, url, jws)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("status=%d want 400; body=%s", resp.StatusCode, string(body))
	}
	var prob map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&prob)
	if prob["type"] != "urn:ietf:params:acme:error:accountDoesNotExist" {
		t.Errorf("problem.type=%v", prob["type"])
	}
}

func TestNewAccount_BadNonce(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-bad-nonce")
	_ = env.DB.Model(&models.Profile{}).Where("name = ?", prof).
		Update("acme_eab_required", 0)

	c := newACMEClient(t, env, prof)
	url := newAccountURL(env, prof)
	jws := c.signed(url, modeJWK, "", "definitely-not-a-real-nonce", map[string]any{})
	resp := c.post(t, url, jws)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status=%d want 400", resp.StatusCode)
	}
	if rn := resp.Header.Get("Replay-Nonce"); rn == "" {
		t.Errorf("server should issue a fresh nonce on badNonce response")
	}
	var prob map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&prob)
	if prob["type"] != "urn:ietf:params:acme:error:badNonce" {
		t.Errorf("problem.type=%v", prob["type"])
	}
}

func TestNewAccount_BadURL(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-bad-url")
	_ = env.DB.Model(&models.Profile{}).Where("name = ?", prof).
		Update("acme_eab_required", 0)

	c := newACMEClient(t, env, prof)
	url := newAccountURL(env, prof)
	// Sign over a URL the request didn't actually hit.
	jws := c.signed(url+"-WRONG", modeJWK, "", c.fetchNonce(), map[string]any{})
	resp := c.post(t, url, jws)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status=%d want 400", resp.StatusCode)
	}
}

func TestNewAccount_EABRequiredMissing(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-eab-miss")
	// AcmeEabRequired defaults to 1; nothing to flip.

	c := newACMEClient(t, env, prof)
	url := newAccountURL(env, prof)
	jws := c.signed(url, modeJWK, "", c.fetchNonce(), map[string]any{})
	resp := c.post(t, url, jws)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("status=%d want 401; body=%s", resp.StatusCode, string(body))
	}
	var prob map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&prob)
	if prob["type"] != "urn:ietf:params:acme:error:externalAccountRequired" {
		t.Errorf("problem.type=%v", prob["type"])
	}
}

func TestNewAccount_EABValid(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-eab-ok")
	var profRow models.Profile
	if err := env.DB.Where("name = ?", prof).First(&profRow).Error; err != nil {
		t.Fatalf("load profile: %v", err)
	}

	// Mint a 256-bit HMAC key.
	macRaw := make([]byte, 32)
	if _, err := rand.Read(macRaw); err != nil {
		t.Fatalf("rand: %v", err)
	}
	macB64 := base64.RawURLEncoding.EncodeToString(macRaw)
	eab := models.AcmeExternalAccountKey{
		ProfileID: profRow.ID,
		KeyID:     "kid-eab-test",
		HMACKey:   macB64,
		Reference: "test-fleet",
	}
	if err := env.DB.Create(&eab).Error; err != nil {
		t.Fatalf("create EAB: %v", err)
	}

	c := newACMEClient(t, env, prof)
	url := newAccountURL(env, prof)

	// Build the inner (HS256) JWS: payload is the outer JWK; protected
	// header carries kid + url. The outer payload then carries the
	// inner JWS as a JSON value under externalAccountBinding.
	innerSigner, err := jose.NewSigner(
		jose.SigningKey{Algorithm: jose.HS256, Key: macRaw},
		(&jose.SignerOptions{
			ExtraHeaders: map[jose.HeaderKey]any{
				"url": url,
			},
		}).WithHeader("kid", eab.KeyID),
	)
	if err != nil {
		t.Fatalf("inner signer: %v", err)
	}
	outerJWKBytes, _ := json.Marshal(c.jwk)
	innerSig, err := innerSigner.Sign(outerJWKBytes)
	if err != nil {
		t.Fatalf("inner sign: %v", err)
	}
	innerFlat := innerSig.FullSerialize()
	var innerObj map[string]any
	_ = json.Unmarshal([]byte(innerFlat), &innerObj)

	payload := map[string]any{
		"termsOfServiceAgreed":   true,
		"externalAccountBinding": innerObj,
	}
	jws := c.signed(url, modeJWK, "", c.fetchNonce(), payload)
	resp := c.post(t, url, jws)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("status=%d want 201; body=%s", resp.StatusCode, string(body))
	}

	// EAB row must be marked bound.
	var reloaded models.AcmeExternalAccountKey
	if err := env.DB.First(&reloaded, eab.ID).Error; err != nil {
		t.Fatalf("reload EAB: %v", err)
	}
	if reloaded.BoundAccountID == 0 {
		t.Errorf("EAB.BoundAccountID was not set after successful new-account")
	}
}

// mustThumbprint mirrors acme/jws.go::jwsThumbprint without depending
// on package internals. Returns the RFC 7638 SHA-256 thumbprint as
// URL-safe base64 (no padding).
func mustThumbprint(t *testing.T, jwk *jose.JSONWebKey) string {
	t.Helper()
	tp, err := jwk.Thumbprint(crypto.SHA256)
	if err != nil {
		t.Fatalf("thumbprint: %v", err)
	}
	return base64.RawURLEncoding.EncodeToString(tp)
}
