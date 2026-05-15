package acme_test

import (
	"crypto/x509"
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
)

// mustEnableAcmeProfile sets up the minimal precondition for any ACME
// request: a CA + a profile with AcmeEnabled=1. Returns the profile
// name to use in URLs.
func mustEnableAcmeProfile(t *testing.T, env *testutil.Env, name string) string {
	t.Helper()

	kt := certutils.KEY_ECDSA
	keyUsage := "32|64"
	extKeyUsage := "1|2"
	ca := models.CA{
		Cn:               "acme-smoke-ca",
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
	if err := env.DB.Where("cn = ?", "acme-smoke-ca").First(&caRow).Error; err != nil {
		t.Fatalf("reload CA: %v", err)
	}

	leafKU := "1|4"
	leafEKU := "1|2"
	prof := models.Profile{
		Name:             name,
		CaID:             caRow.ID,
		Validity:         90,
		KeyType:          &kt,
		KeySize:          256,
		Digest:           x509.ECDSAWithSHA256,
		KeyUsage:         &leafKU,
		ExtendedKeyUsage: &leafEKU,
		DB:               env.DB,
		Ctx:              env.Ctx,
	}
	if _, err := prof.New(); err != nil {
		t.Fatalf("Profile.New: %v", err)
	}
	// AcmeEnabled isn't exposed through Profile.New yet — flip it
	// directly. Once the profile UI lands this happens via the form.
	if err := env.DB.Model(&models.Profile{}).Where("name = ?", name).
		Update("acme_enabled", 1).Error; err != nil {
		t.Fatalf("enable ACME on profile: %v", err)
	}
	return name
}

func TestAcmeDirectory(t *testing.T) {
	env := testutil.NewEnv(t)
	name := mustEnableAcmeProfile(t, env, "acme-smoke")

	resp, err := http.Get(env.Server.URL + "/api/v1/pki/acme/" + name + "/directory")
	if err != nil {
		t.Fatalf("GET /directory: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("status=%d body=%s", resp.StatusCode, string(body))
	}
	if got := resp.Header.Get("Content-Type"); got != "application/json" {
		t.Errorf("Content-Type=%q want application/json", got)
	}

	var doc struct {
		NewNonce   string `json:"newNonce"`
		NewAccount string `json:"newAccount"`
		NewOrder   string `json:"newOrder"`
		RevokeCert string `json:"revokeCert"`
		KeyChange  string `json:"keyChange"`
		Meta       struct {
			ExternalAccountRequired bool `json:"externalAccountRequired"`
		} `json:"meta"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&doc); err != nil {
		t.Fatalf("decode directory: %v", err)
	}

	// Every URL must be absolute and namespaced under this profile.
	for label, u := range map[string]string{
		"newNonce":   doc.NewNonce,
		"newAccount": doc.NewAccount,
		"newOrder":   doc.NewOrder,
		"revokeCert": doc.RevokeCert,
		"keyChange":  doc.KeyChange,
	} {
		if u == "" {
			t.Errorf("directory.%s is empty", label)
		}
	}
	if doc.NewNonce != env.Server.URL+"/api/v1/pki/acme/"+name+"/new-nonce" {
		t.Errorf("newNonce=%q does not match expected mount", doc.NewNonce)
	}
	// Profile defaults: AcmeEabRequired starts at 1 so this should be true.
	if !doc.Meta.ExternalAccountRequired {
		t.Errorf("meta.externalAccountRequired = false, expected true (profile default)")
	}
}

func TestAcmeDirectory_RejectsDisabledProfile(t *testing.T) {
	env := testutil.NewEnv(t)
	name := mustEnableAcmeProfile(t, env, "acme-off")
	// Disable AcmeEnabled on this profile.
	if err := env.DB.Model(&models.Profile{}).Where("name = ?", name).
		Update("acme_enabled", 0).Error; err != nil {
		t.Fatalf("disable ACME on profile: %v", err)
	}

	resp, err := http.Get(env.Server.URL + "/api/v1/pki/acme/" + name + "/directory")
	if err != nil {
		t.Fatalf("GET /directory: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("status=%d want 403; body=%s", resp.StatusCode, string(body))
	}
	if ct := resp.Header.Get("Content-Type"); ct != "application/problem+json" {
		t.Errorf("Content-Type=%q want application/problem+json", ct)
	}
}

func TestAcmeNewNonce(t *testing.T) {
	env := testutil.NewEnv(t)
	name := mustEnableAcmeProfile(t, env, "acme-nonce")

	t.Run("HEAD returns 200 with Replay-Nonce + no-store", func(t *testing.T) {
		resp, err := http.Head(env.Server.URL + "/api/v1/pki/acme/" + name + "/new-nonce")
		if err != nil {
			t.Fatalf("HEAD: %v", err)
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("status=%d want 200", resp.StatusCode)
		}
		if got := resp.Header.Get("Replay-Nonce"); got == "" {
			t.Errorf("missing Replay-Nonce header")
		}
		if got := resp.Header.Get("Cache-Control"); got != "no-store" {
			t.Errorf("Cache-Control=%q want no-store", got)
		}
	})

	t.Run("GET returns 204", func(t *testing.T) {
		resp, err := http.Get(env.Server.URL + "/api/v1/pki/acme/" + name + "/new-nonce")
		if err != nil {
			t.Fatalf("GET: %v", err)
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusNoContent {
			t.Fatalf("status=%d want 204", resp.StatusCode)
		}
		if got := resp.Header.Get("Replay-Nonce"); got == "" {
			t.Errorf("missing Replay-Nonce header")
		}
	})

	t.Run("each request issues a fresh token", func(t *testing.T) {
		seen := map[string]bool{}
		for i := 0; i < 3; i++ {
			resp, _ := http.Head(env.Server.URL + "/api/v1/pki/acme/" + name + "/new-nonce")
			resp.Body.Close()
			tok := resp.Header.Get("Replay-Nonce")
			if tok == "" {
				t.Fatalf("call %d returned no nonce", i)
			}
			if seen[tok] {
				t.Fatalf("duplicate nonce %q on call %d", tok, i)
			}
			seen[tok] = true
		}
	})

	t.Run("issued nonces are persisted", func(t *testing.T) {
		resp, _ := http.Head(env.Server.URL + "/api/v1/pki/acme/" + name + "/new-nonce")
		resp.Body.Close()
		tok := resp.Header.Get("Replay-Nonce")
		var row models.AcmeNonce
		if err := env.DB.Where("token = ?", tok).First(&row).Error; err != nil {
			t.Fatalf("nonce row not found: %v", err)
		}
		if row.ExpiresAt.Before(row.CreatedAt) {
			t.Errorf("expires_at=%v predates created_at=%v", row.ExpiresAt, row.CreatedAt)
		}
	})
}
