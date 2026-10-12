package acme_test

import (
	"io"
	"net/http"
	"testing"

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
