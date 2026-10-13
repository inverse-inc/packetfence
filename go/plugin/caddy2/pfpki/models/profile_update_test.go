package models_test

import (
	"encoding/json"
	"fmt"
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
