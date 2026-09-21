package acme_test

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
)

// bootstrapAcmeAccount runs the full new-account dance against the
// test server and returns the client (cached signer + JWK) together
// with the freshly-minted account URL (kid). Used by every order/authz
// test to skip the new-account boilerplate.
func bootstrapAcmeAccount(t *testing.T, env *testutil.Env, profileName string) (*acmeClient, string) {
	t.Helper()
	// Profile starts with AcmeEnabled flipped on but EAB required by
	// default; the existing helper handles EAB-on so flip it off for
	// the protocol tests — Phase 1 cares about the order flow, not
	// EAB-everywhere.
	if err := env.DB.Model(&models.Profile{}).Where("name = ?", profileName).
		Update("acme_eab_required", 0).Error; err != nil {
		t.Fatalf("disable EAB: %v", err)
	}
	// The allowed identifier list is empty by default; tests below
	// rely on dns being allowed so seed it.
	if err := env.DB.Model(&models.Profile{}).Where("name = ?", profileName).
		Update("acme_allowed_identifiers", "dns,ip").Error; err != nil {
		t.Fatalf("set allowed identifiers: %v", err)
	}

	c := newACMEClient(t, env, profileName)
	url := newAccountURL(env, profileName)
	jws := c.signed(url, modeJWK, "", c.fetchNonce(), map[string]any{
		"termsOfServiceAgreed": true,
	})
	resp := c.post(t, url, jws)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("bootstrap new-account: status=%d body=%s", resp.StatusCode, string(body))
	}
	kid := resp.Header.Get("Location")
	if kid == "" {
		t.Fatalf("bootstrap: missing Location header")
	}
	return c, kid
}

func newOrderURL(env *testutil.Env, profileName string) string {
	return env.Server.URL + "/api/v1/pki/acme/" + profileName + "/new-order"
}

func TestNewOrder_Happy(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-order")
	c, kid := bootstrapAcmeAccount(t, env, prof)

	url := newOrderURL(env, prof)
	payload := map[string]any{
		"identifiers": []map[string]string{
			{"type": "dns", "value": "radius.example.test"},
			{"type": "dns", "value": "alt.example.test"},
		},
	}
	jws := c.signed(url, modeKID, kid, c.fetchNonce(), payload)
	resp := c.post(t, url, jws)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("status=%d want 201; body=%s", resp.StatusCode, string(body))
	}

	loc := resp.Header.Get("Location")
	if loc == "" || !strings.Contains(loc, "/order/") {
		t.Errorf("Location=%q does not look like an order URL", loc)
	}
	if rn := resp.Header.Get("Replay-Nonce"); rn == "" {
		t.Errorf("missing Replay-Nonce")
	}

	var body struct {
		Status         string `json:"status"`
		Identifiers    []map[string]any
		Authorizations []string
		Finalize       string
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode order: %v", err)
	}
	if body.Status != "pending" {
		t.Errorf("status=%q want pending", body.Status)
	}
	if len(body.Identifiers) != 2 {
		t.Errorf("got %d identifiers, want 2", len(body.Identifiers))
	}
	if len(body.Authorizations) != 2 {
		t.Errorf("got %d authzs, want 2", len(body.Authorizations))
	}
	if !strings.HasSuffix(body.Finalize, "/finalize") {
		t.Errorf("finalize=%q missing /finalize suffix", body.Finalize)
	}

	// Persistence check: a real AcmeOrder row + per-identifier authz +
	// per-authz http-01 challenge were written.
	var orderCount, authzCount, challengeCount int64
	env.DB.Model(&models.AcmeOrder{}).Count(&orderCount)
	env.DB.Model(&models.AcmeAuthz{}).Count(&authzCount)
	env.DB.Model(&models.AcmeChallenge{}).Count(&challengeCount)
	if orderCount != 1 || authzCount != 2 || challengeCount != 2 {
		t.Errorf("counts: orders=%d authzs=%d challenges=%d", orderCount, authzCount, challengeCount)
	}
}

func TestNewOrder_RejectsForbiddenIdentifier(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-reject")
	c, kid := bootstrapAcmeAccount(t, env, prof)
	// Override the seeded "dns,ip" so the test's `email` type isn't
	// allowed and the server has to reject it.
	if err := env.DB.Model(&models.Profile{}).Where("name = ?", prof).
		Update("acme_allowed_identifiers", "dns").Error; err != nil {
		t.Fatalf("constrain identifiers: %v", err)
	}

	url := newOrderURL(env, prof)
	payload := map[string]any{
		"identifiers": []map[string]string{
			{"type": "email", "value": "user@example.test"},
		},
	}
	jws := c.signed(url, modeKID, kid, c.fetchNonce(), payload)
	resp := c.post(t, url, jws)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("status=%d want 400; body=%s", resp.StatusCode, string(body))
	}
	var prob map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&prob)
	if prob["type"] != "urn:ietf:params:acme:error:rejectedIdentifier" {
		t.Errorf("problem.type=%v want rejectedIdentifier", prob["type"])
	}
}

func TestOrderByID_PostAsGetRoundTrip(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-order-get")
	c, kid := bootstrapAcmeAccount(t, env, prof)

	// Step 1: POST /new-order to mint an order, capture its Location.
	createURL := newOrderURL(env, prof)
	createJWS := c.signed(createURL, modeKID, kid, c.fetchNonce(), map[string]any{
		"identifiers": []map[string]string{
			{"type": "dns", "value": "echo.example.test"},
		},
	})
	createResp := c.post(t, createURL, createJWS)
	defer createResp.Body.Close()
	if createResp.StatusCode != http.StatusCreated {
		t.Fatalf("create: status=%d", createResp.StatusCode)
	}
	orderURL := createResp.Header.Get("Location")

	// Step 2: POST-as-GET the order URL (empty-string payload) and
	// confirm the server echoes back the same state.
	readJWS := c.signed(orderURL, modeKID, kid, c.fetchNonce(), "")
	readResp := c.post(t, orderURL, readJWS)
	defer readResp.Body.Close()
	if readResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(readResp.Body)
		t.Fatalf("read: status=%d body=%s", readResp.StatusCode, string(body))
	}
	var body struct {
		Status      string `json:"status"`
		Identifiers []map[string]any
	}
	_ = json.NewDecoder(readResp.Body).Decode(&body)
	if body.Status != "pending" {
		t.Errorf("status=%q want pending", body.Status)
	}
	if len(body.Identifiers) != 1 || body.Identifiers[0]["value"] != "echo.example.test" {
		t.Errorf("identifiers don't round-trip: %+v", body.Identifiers)
	}
}

func TestOrderByID_RejectsForeignAccount(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-foreign")
	owner, ownerKID := bootstrapAcmeAccount(t, env, prof)

	// Owner creates an order.
	createURL := newOrderURL(env, prof)
	createJWS := owner.signed(createURL, modeKID, ownerKID, owner.fetchNonce(), map[string]any{
		"identifiers": []map[string]string{
			{"type": "dns", "value": "secret.example.test"},
		},
	})
	cr := owner.post(t, createURL, createJWS)
	cr.Body.Close()
	if cr.StatusCode != http.StatusCreated {
		t.Fatalf("owner create: status=%d", cr.StatusCode)
	}
	orderURL := cr.Header.Get("Location")

	// Stranger spins up a fresh account on the same profile.
	stranger, strangerKID := bootstrapAcmeAccountAsNewKey(t, env, prof)
	readJWS := stranger.signed(orderURL, modeKID, strangerKID, stranger.fetchNonce(), "")
	resp := stranger.post(t, orderURL, readJWS)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("status=%d want 401; body=%s", resp.StatusCode, string(body))
	}
}

func TestAuthzByID_ReturnsChallenges(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-authz")
	c, kid := bootstrapAcmeAccount(t, env, prof)

	// Mint an order so we have an authz URL to fetch.
	createURL := newOrderURL(env, prof)
	createJWS := c.signed(createURL, modeKID, kid, c.fetchNonce(), map[string]any{
		"identifiers": []map[string]string{
			{"type": "dns", "value": "auth.example.test"},
		},
	})
	cr := c.post(t, createURL, createJWS)
	defer cr.Body.Close()
	if cr.StatusCode != http.StatusCreated {
		t.Fatalf("create order: status=%d", cr.StatusCode)
	}
	var orderBody struct {
		Authorizations []string `json:"authorizations"`
	}
	if err := json.NewDecoder(cr.Body).Decode(&orderBody); err != nil {
		t.Fatalf("decode order: %v", err)
	}
	if len(orderBody.Authorizations) != 1 {
		t.Fatalf("got %d authzs, want 1", len(orderBody.Authorizations))
	}
	authzURL := orderBody.Authorizations[0]

	readJWS := c.signed(authzURL, modeKID, kid, c.fetchNonce(), "")
	rd := c.post(t, authzURL, readJWS)
	defer rd.Body.Close()
	if rd.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(rd.Body)
		t.Fatalf("status=%d body=%s", rd.StatusCode, string(body))
	}
	var authBody struct {
		Identifier struct {
			Type, Value string
		}
		Status     string
		Challenges []struct {
			Type   string
			URL    string
			Status string
			Token  string
		}
	}
	if err := json.NewDecoder(rd.Body).Decode(&authBody); err != nil {
		t.Fatalf("decode authz: %v", err)
	}
	if authBody.Identifier.Type != "dns" || authBody.Identifier.Value != "auth.example.test" {
		t.Errorf("identifier round-trip mismatch: %+v", authBody.Identifier)
	}
	if authBody.Status != "pending" {
		t.Errorf("status=%q want pending", authBody.Status)
	}
	if len(authBody.Challenges) != 1 {
		t.Fatalf("got %d challenges, want 1", len(authBody.Challenges))
	}
	ch := authBody.Challenges[0]
	if ch.Type != "http-01" {
		t.Errorf("challenge.type=%q want http-01", ch.Type)
	}
	if ch.Token == "" {
		t.Errorf("challenge.token is empty")
	}
	if !strings.Contains(ch.URL, "/chall/") {
		t.Errorf("challenge.url=%q does not point at /chall/", ch.URL)
	}
}

// bootstrapAcmeAccountAsNewKey is bootstrapAcmeAccount but with a
// fresh keypair, so two accounts can coexist on one profile for the
// foreign-account authorization test.
func bootstrapAcmeAccountAsNewKey(t *testing.T, env *testutil.Env, profileName string) (*acmeClient, string) {
	t.Helper()
	c := newACMEClient(t, env, profileName)
	url := newAccountURL(env, profileName)
	jws := c.signed(url, modeJWK, "", c.fetchNonce(), map[string]any{})
	resp := c.post(t, url, jws)
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("second bootstrap: status=%d body=%s", resp.StatusCode, string(body))
	}
	return c, resp.Header.Get("Location")
}
