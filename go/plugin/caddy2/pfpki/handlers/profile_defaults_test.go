package handlers_test

import (
	"crypto/x509"
	"fmt"
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
)

// A template created with 0 in a column that has a non-zero database
// default (EAB off for Apple devices, no renewal mail, renewal always
// allowed) keeps the 0; columns not sent keep their default.
func TestProfile_CreateKeepsZeroValues(t *testing.T) {
	env := testutil.NewEnv(t)
	ca := mustCreateCAFromHTTP(t, env, "defaults-ca", certutils.KEY_ECDSA, 256, x509.ECDSAWithSHA256)

	create := func(name, extra string) models.Profile {
		t.Helper()
		status, body := doJSON(t, env, "POST", "/api/v1/pki/profiles/", fmt.Sprintf(`{
			"name": %q, "ca_id": "%d", "validity": "30", "key_type": "%d", "key_size": "256",
			"digest": "%d", "key_usage": "1", "extended_key_usage": "2"%s}`,
			name, ca.ID, int(certutils.KEY_ECDSA), int(x509.ECDSAWithSHA256), extra))
		if status/100 != 2 {
			t.Fatalf("POST /pki/profiles %s -> %d:\n%s", name, status, body)
		}
		var p models.Profile
		if err := env.DB.Where("name = ?", name).First(&p).Error; err != nil {
			t.Fatal(err)
		}
		return p
	}

	zero := create("zeroes", `, "acme_eab_required": 0, "renewal_mail": "0",
		"days_before_renewal": "0", "scep_days_before_renewal": "0", "revoked_valid_until": "0"`)
	if zero.AcmeEabRequired != 0 || zero.RenewalMail != 0 || zero.DaysBeforeRenewal != 0 ||
		zero.SCEPDaysBeforeRenewal != 0 || zero.RevokedValidUntil != 0 {
		t.Errorf("zero values not kept: eab=%d renewal_mail=%d days_before_renewal=%d scep_days=%d revoked_valid_until=%d",
			zero.AcmeEabRequired, zero.RenewalMail, zero.DaysBeforeRenewal, zero.SCEPDaysBeforeRenewal, zero.RevokedValidUntil)
	}
	if zero.AcmeAccountExpiry != 365 || zero.DaysBeforeRenewalMail != 14 {
		t.Errorf("defaults of the columns not sent lost: acme_account_expiry=%d days_before_renewal_mail=%d",
			zero.AcmeAccountExpiry, zero.DaysBeforeRenewalMail)
	}

	def := create("defaults", "")
	if def.AcmeEabRequired != 1 || def.RenewalMail != 1 || def.DaysBeforeRenewal != 14 || def.RevokedValidUntil != 14 {
		t.Errorf("defaults not applied: eab=%d renewal_mail=%d days_before_renewal=%d revoked_valid_until=%d",
			def.AcmeEabRequired, def.RenewalMail, def.DaysBeforeRenewal, def.RevokedValidUntil)
	}

	set := create("explicit", `, "acme_eab_required": 1, "days_before_renewal": "30"`)
	if set.AcmeEabRequired != 1 || set.DaysBeforeRenewal != 30 {
		t.Errorf("explicit values: eab=%d days_before_renewal=%d", set.AcmeEabRequired, set.DaysBeforeRenewal)
	}
}
