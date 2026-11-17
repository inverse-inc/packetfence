package models_test

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
)

func patchProfile(t *testing.T, env *testutil.Env, id uint, body string) models.Profile {
	t.Helper()
	p := models.Profile{DB: env.DB, Ctx: env.Ctx}
	if err := json.Unmarshal([]byte(body), &p); err != nil {
		t.Fatalf("decode %s: %v", body, err)
	}
	if _, err := p.Update(map[string]string{"id": fmt.Sprint(id)}); err != nil {
		t.Fatalf("Update(%s): %v", body, err)
	}
	var stored models.Profile
	if err := env.DB.First(&stored, id).Error; err != nil {
		t.Fatal(err)
	}
	return stored
}

// A PATCH only changes the fields it sends, renewal_mail_days included.
func TestProfileUpdate_OnlySentFields(t *testing.T) {
	env := testutil.NewEnv(t)
	_, prof := newTestProfile(t, env, "patch")
	if err := env.DB.Model(&prof).Updates(map[string]interface{}{"est_password": "s3cret", "validity": 90, "renewal_mail": 1}).Error; err != nil {
		t.Fatal(err)
	}

	stored := patchProfile(t, env, prof.ID, `{"renewal_mail_days":"14,7,1"}`)
	if stored.RenewalMailDays != "14,7,1" {
		t.Errorf("renewal_mail_days = %q, want 14,7,1", stored.RenewalMailDays)
	}
	if stored.EstPassword != "s3cret" || stored.Validity != 90 || stored.Mail != "leaf@example.test" || stored.Organisation != "Acme" || stored.RenewalMail != 1 || stored.ScepServerID != 1 {
		t.Errorf("fields the PATCH omitted changed: %+v", stored)
	}
	if stored.KeyUsage == nil || *stored.KeyUsage != "1|4" {
		t.Errorf("key_usage changed: %v", stored.KeyUsage)
	}

	// A field sent as zero/empty is stored as such.
	stored = patchProfile(t, env, prof.ID, `{"renewal_mail":"0","mail":"","renewal_mail_days":""}`)
	if stored.RenewalMail != 0 || stored.Mail != "" || stored.RenewalMailDays != "" {
		t.Errorf("fields sent empty: renewal_mail=%d mail=%q renewal_mail_days=%q", stored.RenewalMail, stored.Mail, stored.RenewalMailDays)
	}
	if stored.EstPassword != "s3cret" {
		t.Errorf("est_password changed: %q", stored.EstPassword)
	}
}

// The EST password is write-only, like the HSM PINs: the API never
// returns it, and a PATCH without it (or with it empty) keeps it.
func TestProfile_ESTPasswordWriteOnly(t *testing.T) {
	env := testutil.NewEnv(t)
	_, prof := newTestProfile(t, env, "est-wo")
	stored := patchProfile(t, env, prof.ID, `{"est_password":"s3cret"}`)
	if stored.EstPassword != "s3cret" {
		t.Fatalf("est_password = %q, want s3cret", stored.EstPassword)
	}

	for _, req := range []struct{ method, path, body string }{
		{http.MethodGet, fmt.Sprintf("/api/v1/pki/profile/%d", prof.ID), ""},
		{http.MethodGet, "/api/v1/pki/profiles", ""},
		{http.MethodPost, "/api/v1/pki/profiles/search", `{"query":{"op":"and","values":[{"field":"name","op":"equals","value":"est-wo"}]}}`},
		{http.MethodPatch, fmt.Sprintf("/api/v1/pki/profile/%d", prof.ID), `{"est_password":""}`},
	} {
		r, _ := http.NewRequest(req.method, env.Server.URL+req.path, strings.NewReader(req.body))
		resp, err := http.DefaultClient.Do(r)
		if err != nil {
			t.Fatal(err)
		}
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK || !strings.Contains(string(body), `"est-wo"`) {
			t.Fatalf("%s %s: status %d (%s)", req.method, req.path, resp.StatusCode, body)
		}
		if strings.Contains(string(body), "s3cret") || strings.Contains(string(body), "est_password") {
			t.Errorf("%s %s returned the EST password: %s", req.method, req.path, body)
		}
	}

	stored = patchProfile(t, env, prof.ID, `{"est_username":"device"}`)
	if stored.EstPassword != "s3cret" {
		t.Errorf("est_password = %q after a PATCH without it, want s3cret", stored.EstPassword)
	}
	stored = patchProfile(t, env, prof.ID, `{"est_password":""}`)
	if stored.EstPassword != "s3cret" {
		t.Errorf("est_password = %q after a PATCH with it empty, want s3cret", stored.EstPassword)
	}
	stored = patchProfile(t, env, prof.ID, `{"est_password":"n3w"}`)
	if stored.EstPassword != "n3w" {
		t.Errorf("est_password = %q, want n3w", stored.EstPassword)
	}
}
