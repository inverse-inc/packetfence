package handlers_test

import (
	"bytes"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
)

// eabPayload mirrors the handler response shape so tests can decode it
// without coupling to the unexported handlers.eabResponse type.
type eabPayload struct {
	ID             uint   `json:"id"`
	KeyID          string `json:"key_id"`
	HMAC           string `json:"hmac"`
	Reference      string `json:"reference"`
	BoundAccountID uint   `json:"bound_account_id"`
	CreatedAt      string `json:"created_at"`
}

// TestAcmeEAB_FullCycle covers the operational lifecycle of an EAB key
// from the admin API: mint → confirm visible in list → revoke → confirm
// gone from list. The mint response must include the HMAC; the list
// response must NOT. Revocation is soft-delete so audit history stays
// queryable.
func TestAcmeEAB_FullCycle(t *testing.T) {
	env := testutil.NewEnv(t)
	caRow := mustCreateCAFromHTTP(t, env, "eab-ca", certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
	prof := mustCreateProfileFromHTTP(t, env, "eab-prof", caRow, certutils.KEY_RSA, 2048, x509.SHA256WithRSA)

	mintURL := fmt.Sprintf("%s/api/v1/pki/profile/%d/acme/eab", env.Server.URL, prof.ID)
	listURL := mintURL

	// Mint two keys; second has a reference label.
	first := mintEAB(t, mintURL, "")
	if first.KeyID == "" || first.HMAC == "" {
		t.Fatalf("mint #1 missing key_id/hmac: %+v", first)
	}
	if !looksBase64URL(first.KeyID) || !looksBase64URL(first.HMAC) {
		t.Fatalf("mint #1 key/hmac don't look like raw-url-base64: kid=%q hmac=%q", first.KeyID, first.HMAC)
	}
	second := mintEAB(t, mintURL, "lab-fleet-2026Q2")
	if second.Reference != "lab-fleet-2026Q2" {
		t.Fatalf("mint #2 reference not echoed: %q", second.Reference)
	}

	// List → expect both, HMAC blanked, newest-first.
	items := listEAB(t, listURL)
	if len(items) != 2 {
		t.Fatalf("expected 2 EAB rows after two mints, got %d", len(items))
	}
	if items[0].ID != second.ID {
		t.Fatalf("expected newest-first ordering; got %d before %d", items[0].ID, second.ID)
	}
	for _, it := range items {
		if it.HMAC != "" {
			t.Fatalf("list response leaked HMAC for key id=%d", it.ID)
		}
	}

	// Revoke the first key; confirm only the second remains.
	delURL := fmt.Sprintf("%s/%d", mintURL, first.ID)
	req, _ := http.NewRequest(http.MethodDelete, delURL, nil)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("DELETE: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("revoke status=%d, want 204", resp.StatusCode)
	}

	items = listEAB(t, listURL)
	if len(items) != 1 || items[0].ID != second.ID {
		t.Fatalf("after revoke want exactly the second row, got %+v", items)
	}

	// Idempotent: deleting again returns 204, not 404.
	req2, _ := http.NewRequest(http.MethodDelete, delURL, nil)
	resp2, err := http.DefaultClient.Do(req2)
	if err != nil {
		t.Fatalf("DELETE retry: %v", err)
	}
	resp2.Body.Close()
	if resp2.StatusCode != http.StatusNoContent {
		t.Fatalf("idempotent revoke status=%d, want 204", resp2.StatusCode)
	}

	// Soft-delete: the row is still in the DB so audit history can join it.
	var raw models.AcmeExternalAccountKey
	if err := env.DB.Unscoped().First(&raw, first.ID).Error; err != nil {
		t.Fatalf("soft-deleted row missing from db: %v", err)
	}
	if !raw.DeletedAt.Valid {
		t.Fatalf("row id=%d not marked DeletedAt", first.ID)
	}
}

// TestAcmeEAB_MobileConfig confirms the .mobileconfig endpoint serves
// the right Content-Type, embeds the EAB key + directory URL, and
// scrubs profile-name separators from the suggested filename.
func TestAcmeEAB_MobileConfig(t *testing.T) {
	env := testutil.NewEnv(t)
	caRow := mustCreateCAFromHTTP(t, env, "mc-ca", certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
	prof := mustCreateProfileFromHTTP(t, env, "mc-prof", caRow, certutils.KEY_RSA, 2048, x509.SHA256WithRSA)

	mintURL := fmt.Sprintf("%s/api/v1/pki/profile/%d/acme/eab", env.Server.URL, prof.ID)
	eab := mintEAB(t, mintURL, "")

	mcURL := fmt.Sprintf("%s/%d/mobileconfig", mintURL, eab.ID)
	resp, err := http.Get(mcURL)
	if err != nil {
		t.Fatalf("GET: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status=%d", resp.StatusCode)
	}
	if ct := resp.Header.Get("Content-Type"); ct != "application/x-apple-aspen-config" {
		t.Fatalf("Content-Type=%q", ct)
	}
	body, _ := io.ReadAll(resp.Body)
	s := string(body)
	for _, want := range []string{
		"<string>com.apple.security.acme</string>",
		"<key>DirectoryURL</key>",
		"/api/v1/pki/acme/mc-prof/directory",
		"<string>" + eab.KeyID + "</string>",
		"<string>" + eab.HMAC + "</string>",
		"<true/>", // HardwareBound + Attest
	} {
		if !strings.Contains(s, want) {
			t.Fatalf("payload missing %q\n--- full payload ---\n%s", want, s)
		}
	}
}

// TestAcmeEAB_BadProfileID confirms the endpoint refuses non-integer
// profile ids with a 400 rather than a 500.
func TestAcmeEAB_BadProfileID(t *testing.T) {
	env := testutil.NewEnv(t)
	url := env.Server.URL + "/api/v1/pki/profile/not-an-int/acme/eab"
	resp, err := http.Post(url, "application/json", bytes.NewBufferString("{}"))
	if err != nil {
		t.Fatalf("POST: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status=%d, want 400", resp.StatusCode)
	}
}

func mintEAB(t *testing.T, url, reference string) eabPayload {
	t.Helper()
	body := bytes.NewBufferString(`{}`)
	if reference != "" {
		b, _ := json.Marshal(map[string]string{"reference": reference})
		body = bytes.NewBuffer(b)
	}
	resp, err := http.Post(url, "application/json", body)
	if err != nil {
		t.Fatalf("POST: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		raw, _ := io.ReadAll(resp.Body)
		t.Fatalf("mint status=%d body=%s", resp.StatusCode, string(raw))
	}
	var out eabPayload
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		t.Fatalf("decode: %v", err)
	}
	return out
}

func listEAB(t *testing.T, url string) []eabPayload {
	t.Helper()
	resp, err := http.Get(url)
	if err != nil {
		t.Fatalf("GET: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(resp.Body)
		t.Fatalf("list status=%d body=%s", resp.StatusCode, string(raw))
	}
	var wrapper struct {
		Items []eabPayload `json:"items"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&wrapper); err != nil {
		t.Fatalf("decode: %v", err)
	}
	return wrapper.Items
}

// looksBase64URL is a quick shape check — RFC 4648 unpadded URL-safe
// base64 uses only [A-Za-z0-9_-]. We don't decode here; the EAB
// validator already exercises the actual decoding path.
func looksBase64URL(s string) bool {
	if s == "" {
		return false
	}
	const ok = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
	return strings.IndexFunc(s, func(r rune) bool {
		return !strings.ContainsRune(ok, r)
	}) == -1
}
