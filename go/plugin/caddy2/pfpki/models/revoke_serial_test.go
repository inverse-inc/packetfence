package models_test

import (
	"crypto/x509"
	"fmt"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
)

// newTestProfile creates a CA and a profile under it.
func newTestProfile(t *testing.T, env *testutil.Env, name string) (models.CA, models.Profile) {
	t.Helper()
	caRow := mustCreateCA(t, env, name+"-ca", certutils.KEY_ECDSA, 256, x509.ECDSAWithSHA256)
	p := profileTemplate(name, caRow, certutils.KEY_ECDSA, 256, x509.ECDSAWithSHA256)
	p.DB, p.Ctx = env.DB, env.Ctx
	info, err := p.New()
	if err != nil {
		t.Fatalf("Profile.New(%s): %v", name, err)
	}
	return caRow, info.Entries.([]models.Profile)[0]
}

// insertCertRow stores a bare certificate row (no PEM) for lookups.
func insertCertRow(t *testing.T, env *testutil.Env, caRow models.CA, prof models.Profile, cn, serial string) models.Cert {
	t.Helper()
	row := models.Cert{Cn: cn, CaID: caRow.ID, CaName: caRow.Cn, ProfileID: prof.ID, ProfileName: prof.Name,
		SerialNumber: serial, ValidUntil: time.Now().AddDate(0, 0, 30), NotBefore: time.Now()}
	if err := env.DB.Omit("Ca", "Profile").Create(&row).Error; err != nil {
		t.Fatalf("insert cert %s: %v", cn, err)
	}
	return row
}

// A decimal serial must not also match the cert whose serial is the same
// digits read as hex: "100" is 100, not 0x100 = 256.
func TestRevokeBySerial_DecimalIsNotHex(t *testing.T) {
	env := testutil.NewEnv(t)
	caRow, prof := newTestProfile(t, env, "serial")
	insertCertRow(t, env, caRow, prof, "dev-256", "256")
	insertCertRow(t, env, caRow, prof, "dev-100", "100")

	helper := models.Cert{DB: env.DB, Ctx: env.Ctx}
	found, err := helper.RevokeBySerial(caRow.Cn, "100", 0)
	if err != nil || !found {
		t.Fatalf("RevokeBySerial(100): found=%v err=%v", found, err)
	}
	var live []models.Cert
	env.DB.Find(&live)
	if len(live) != 1 || live[0].Cn != "dev-256" {
		t.Fatalf("live certs after revoking 100: %+v", live)
	}

	// The hex form of 256 still finds it.
	if found, err := helper.RevokeBySerial(caRow.Cn, "01:00", 0); err != nil || !found {
		t.Fatalf("RevokeBySerial(01:00): found=%v err=%v", found, err)
	}
}

// Revoke keeps the certificate fields, keeps a superseded certificate
// valid for the profile's RevokedValidUntil days, revokes it at once for
// any other reason, and doesn't record anything when
// no certificate matches.
func TestCertRevoke_MovesRow(t *testing.T) {
	env := testutil.NewEnv(t)
	caRow, prof := newTestProfile(t, env, "revoke")
	if err := env.DB.Model(&prof).Update("revoked_valid_until", 30).Error; err != nil {
		t.Fatal(err)
	}
	row := insertCertRow(t, env, caRow, prof, "dev-1", "7")
	env.DB.Model(&row).Updates(map[string]interface{}{"locality": "Montreal", "postal_code": "H2X"})

	helper := models.Cert{DB: env.DB, Ctx: env.Ctx}
	if _, err := helper.Revoke(map[string]string{"id": "999", "reason": "0"}); err == nil {
		t.Fatal("revoking a missing certificate succeeded")
	}
	var n int64
	env.DB.Model(&models.RevokedCert{}).Count(&n)
	if n != 0 {
		t.Fatalf("%d revoked rows after revoking a missing certificate", n)
	}

	keyCompromise := insertCertRow(t, env, caRow, prof, "dev-2", "8")
	if _, err := helper.Revoke(map[string]string{"id": itoaUint(keyCompromise.ID), "reason": "1"}); err != nil {
		t.Fatalf("Revoke: %v", err)
	}
	var compromised models.RevokedCert
	env.DB.Where("cn = ?", "dev-2").First(&compromised)
	if time.Since(compromised.Revoked) < 0 || time.Since(compromised.Revoked) > time.Minute {
		t.Errorf("key compromise revoked at %v, want now", compromised.Revoked)
	}

	if _, err := helper.Revoke(map[string]string{"id": itoaUint(row.ID), "reason": "4"}); err != nil {
		t.Fatalf("Revoke: %v", err)
	}
	var revoked []models.RevokedCert
	env.DB.Where("cn = ?", "dev-1").Find(&revoked)
	if len(revoked) != 1 {
		t.Fatalf("revoked rows: %d", len(revoked))
	}
	r := revoked[0]
	if r.PostalCode != "H2X" || r.Locality != "Montreal" || r.CRLReason != 4 || r.SerialNumber != "7" {
		t.Errorf("revoked row: %+v", r)
	}
	if d := time.Until(r.Revoked); d < 29*24*time.Hour || d > 31*24*time.Hour {
		t.Errorf("revoked until %v, want ~30 days from now", r.Revoked)
	}
	env.DB.Model(&models.Cert{}).Count(&n)
	if n != 0 {
		t.Errorf("%d live certs left", n)
	}
}

func itoaUint(n uint) string { return fmt.Sprint(n) }
