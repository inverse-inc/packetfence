package acme_test

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"encoding/json"
	"io"
	"net/http"
	"testing"
	"time"

	jose "github.com/go-jose/go-jose/v4"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"gorm.io/gorm"
)

// TestAccount_UniqueKeyPerProfile: the schema refuses a second account
// row for the same key on one profile.
func TestAccount_UniqueKeyPerProfile(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-acct-unique")
	var p models.Profile
	env.DB.Where("name = ?", prof).First(&p)

	a := models.AcmeAccount{ProfileID: p.ID, KeyID: "kid-a", KeyThumbprint: "same"}
	if err := env.DB.Create(&a).Error; err != nil {
		t.Fatalf("first account: %v", err)
	}
	b := models.AcmeAccount{ProfileID: p.ID, KeyID: "kid-b", KeyThumbprint: "same"}
	if err := env.DB.Create(&b).Error; err == nil {
		t.Fatalf("second account with the same key on the same profile was accepted")
	}
}

// TestNewAccount_LostRaceReturnsExisting: when a concurrent request
// registers the same key between the lookup and the insert, new-account
// returns that account (200 + Location) instead of a 500.
func TestNewAccount_LostRaceReturnsExisting(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-acct-race")
	_ = env.DB.Model(&models.Profile{}).Where("name = ?", prof).Update("acme_eab_required", 0)
	var p models.Profile
	env.DB.Where("name = ?", prof).First(&p)

	c := newACMEClient(t, env, prof)
	thumb := mustThumbprint(t, c.jwk)
	const winnerKID = "https://acme.example/account/winner"

	// Commit a competing row for the same key right before the
	// handler's own insert.
	raced := false
	err := env.DB.Callback().Create().Before("gorm:create").Register("test:race", func(db *gorm.DB) {
		if raced || db.Statement.Table != "pki_acme_accounts" {
			return
		}
		raced = true
		if err := env.DB.Create(&models.AcmeAccount{
			ProfileID: p.ID, KeyID: winnerKID, KeyThumbprint: thumb, Status: "valid",
		}).Error; err != nil {
			t.Errorf("insert competing account: %v", err)
		}
	})
	if err != nil {
		t.Fatalf("register callback: %v", err)
	}
	t.Cleanup(func() { _ = env.DB.Callback().Create().Remove("test:race") })

	url := newAccountURL(env, prof)
	resp := c.post(t, url, c.signed(url, modeJWK, "", c.fetchNonce(), map[string]any{}))
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("status=%d want 200; body=%s", resp.StatusCode, string(body))
	}
	if loc := resp.Header.Get("Location"); loc != winnerKID {
		t.Fatalf("Location=%q want %q", loc, winnerKID)
	}
	var n int64
	env.DB.Model(&models.AcmeAccount{}).Where("key_thumbprint = ?", thumb).Count(&n)
	if n != 1 {
		t.Fatalf("%d accounts for one key", n)
	}
}

// postJSON signs payload with c under kid, posts it to url and decodes
// the JSON response into out (when non-nil). Returns the response with
// its body consumed.
func postJSON(t *testing.T, c *acmeClient, kid, url string, payload, out any) *http.Response {
	t.Helper()
	resp := c.post(t, url, c.signed(url, modeKID, kid, c.fetchNonce(), payload))
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if out != nil {
		_ = json.Unmarshal(body, out)
	}
	return resp
}

// TestAccount_UpdateAndDeactivate: contacts can be updated, and a
// deactivated account's kid is refused on every later request,
// new-account with the same key included.
func TestAccount_UpdateAndDeactivate(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-acct-update")
	c, kid := bootstrapAcmeAccount(t, env, prof)

	var acct struct {
		Status  string
		Contact []string
	}
	resp := postJSON(t, c, kid, kid, map[string]any{"contact": []string{"mailto:ops@example.test"}}, &acct)
	if resp.StatusCode != http.StatusOK || len(acct.Contact) != 1 || acct.Contact[0] != "mailto:ops@example.test" {
		t.Fatalf("contact update: status=%d account=%+v", resp.StatusCode, acct)
	}
	var row models.AcmeAccount
	env.DB.Where("key_id = ?", kid).First(&row)
	if row.Contact != `["mailto:ops@example.test"]` {
		t.Fatalf("stored contact=%q", row.Contact)
	}

	if resp := postJSON(t, c, kid, kid, map[string]any{"status": "valid"}, nil); resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status=valid update: status=%d want 400", resp.StatusCode)
	}

	resp = postJSON(t, c, kid, kid, map[string]any{"status": "deactivated"}, &acct)
	if resp.StatusCode != http.StatusOK || acct.Status != "deactivated" {
		t.Fatalf("deactivate: status=%d account=%+v", resp.StatusCode, acct)
	}

	url := newOrderURL(env, prof)
	expectProblem(t, c.post(t, url, c.signed(url, modeKID, kid, c.fetchNonce(), map[string]any{
		"identifiers": []map[string]string{{"type": "dns", "value": "a.example.test"}},
	})), http.StatusUnauthorized, "unauthorized")
	expectProblem(t, c.post(t, kid, c.signed(kid, modeKID, kid, c.fetchNonce(), "")),
		http.StatusUnauthorized, "unauthorized")
	na := newAccountURL(env, prof)
	expectProblem(t, c.post(t, na, c.signed(na, modeJWK, "", c.fetchNonce(), map[string]any{})),
		http.StatusUnauthorized, "unauthorized")
}

// TestAccount_ExpiredRefused: an expired account's kid is refused; a
// new-account from the same key renews it.
func TestAccount_ExpiredRefused(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-acct-expired")
	c, kid := bootstrapAcmeAccount(t, env, prof)
	env.DB.Model(&models.AcmeAccount{}).Where("key_id = ?", kid).
		Update("expires_at", time.Now().Add(-time.Minute))

	expectProblem(t, c.post(t, kid, c.signed(kid, modeKID, kid, c.fetchNonce(), "")),
		http.StatusUnauthorized, "unauthorized")

	na := newAccountURL(env, prof)
	resp := c.post(t, na, c.signed(na, modeJWK, "", c.fetchNonce(), map[string]any{}))
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK || resp.Header.Get("Location") != kid {
		t.Fatalf("re-register: status=%d Location=%q", resp.StatusCode, resp.Header.Get("Location"))
	}
	if resp := postJSON(t, c, kid, kid, "", nil); resp.StatusCode != http.StatusOK {
		t.Fatalf("after renewal: status=%d want 200", resp.StatusCode)
	}
}

// TestAccount_OrdersList: the orders URL lists the account's orders and
// nothing else.
func TestAccount_OrdersList(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-acct-orders")
	a, kidA := bootstrapAcmeAccount(t, env, prof)
	b, kidB := bootstrapAcmeAccountAsNewKey(t, env, prof)

	newOrder := func(c *acmeClient, kid, name string) string {
		url := newOrderURL(env, prof)
		resp := postJSON(t, c, kid, url, map[string]any{
			"identifiers": []map[string]string{{"type": "dns", "value": name}},
		}, nil)
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("new-order %s: status=%d", name, resp.StatusCode)
		}
		return resp.Header.Get("Location")
	}
	want := []string{newOrder(a, kidA, "one.example.test"), newOrder(a, kidA, "two.example.test")}
	newOrder(b, kidB, "other.example.test")

	var acct struct{ Orders string }
	postJSON(t, a, kidA, kidA, "", &acct)
	if acct.Orders != kidA+"/orders" {
		t.Fatalf("account orders URL=%q", acct.Orders)
	}
	var list struct{ Orders []string }
	resp := postJSON(t, a, kidA, acct.Orders, "", &list)
	if resp.StatusCode != http.StatusOK || len(list.Orders) != 2 || list.Orders[0] != want[0] || list.Orders[1] != want[1] {
		t.Fatalf("orders list: status=%d got=%v want=%v", resp.StatusCode, list.Orders, want)
	}
	// Another account can't read it.
	expectProblem(t, b.post(t, acct.Orders, b.signed(acct.Orders, modeKID, kidB, b.fetchNonce(), "")),
		http.StatusUnauthorized, "unauthorized")
}

// keyChangeURL is the directory's keyChange endpoint.
func keyChangeURL(env *testutil.Env, prof string) string {
	return env.Server.URL + "/api/v1/pki/acme/" + prof + "/key-change"
}

// innerKeyChange builds the §7.3.5 inner JWS: signed by newKey with
// the key embedded, the given url and no nonce.
func innerKeyChange(t *testing.T, newKey *ecdsa.PrivateKey, url, account string, oldKey *jose.JSONWebKey) json.RawMessage {
	t.Helper()
	signer, err := jose.NewSigner(jose.SigningKey{Algorithm: jose.ES256, Key: newKey},
		&jose.SignerOptions{EmbedJWK: true, ExtraHeaders: map[jose.HeaderKey]any{"url": url}})
	if err != nil {
		t.Fatalf("inner signer: %v", err)
	}
	body, _ := json.Marshal(map[string]any{"account": account, "oldKey": oldKey})
	sig, err := signer.Sign(body)
	if err != nil {
		t.Fatalf("inner sign: %v", err)
	}
	return json.RawMessage(sig.FullSerialize())
}

// TestKeyChange: the account key rolls over to the new key, which then
// authenticates the same kid while the old one no longer does; a key
// held by another account is refused with 409 and that account's URL.
func TestKeyChange(t *testing.T) {
	env := testutil.NewEnv(t)
	prof := mustEnableAcmeProfile(t, env, "acme-keychange")
	c, kid := bootstrapAcmeAccount(t, env, prof)
	other, otherKID := bootstrapAcmeAccountAsNewKey(t, env, prof)
	url := keyChangeURL(env, prof)

	// Inner url must equal the outer one.
	newKey, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	expectProblem(t, c.post(t, url, c.signed(url, modeKID, kid, c.fetchNonce(),
		innerKeyChange(t, newKey, url+"x", kid, c.jwk))), http.StatusBadRequest, "malformed")
	// oldKey must be the current key.
	expectProblem(t, c.post(t, url, c.signed(url, modeKID, kid, c.fetchNonce(),
		innerKeyChange(t, newKey, url, kid, other.jwk))), http.StatusBadRequest, "malformed")
	// The new key may not belong to another account.
	conflict := c.post(t, url, c.signed(url, modeKID, kid, c.fetchNonce(),
		innerKeyChange(t, other.key, url, kid, c.jwk)))
	if loc := conflict.Header.Get("Location"); loc != otherKID {
		t.Fatalf("conflict Location=%q want %q", loc, otherKID)
	}
	expectProblem(t, conflict, http.StatusConflict, "malformed")

	resp := c.post(t, url, c.signed(url, modeKID, kid, c.fetchNonce(), innerKeyChange(t, newKey, url, kid, c.jwk)))
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK || resp.Header.Get("Location") != kid {
		t.Fatalf("key-change: status=%d Location=%q", resp.StatusCode, resp.Header.Get("Location"))
	}

	// Old key no longer authenticates the account, the new one does.
	expectProblem(t, c.post(t, kid, c.signed(kid, modeKID, kid, c.fetchNonce(), "")),
		http.StatusBadRequest, "malformed")
	rolled := &acmeClient{t: t, env: env, profile: prof, key: newKey, jwk: &jose.JSONWebKey{Key: newKey.Public()}}
	if resp := postJSON(t, rolled, kid, kid, "", nil); resp.StatusCode != http.StatusOK {
		t.Fatalf("new key: status=%d want 200", resp.StatusCode)
	}
	var row models.AcmeAccount
	env.DB.Where("key_id = ?", kid).First(&row)
	if row.KeyThumbprint != mustThumbprint(t, rolled.jwk) {
		t.Fatalf("stored thumbprint was not rolled over")
	}
}
