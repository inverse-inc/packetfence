package models_test

import (
	"context"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

func TestCheckRenewal_Schedule(t *testing.T) {
	env := testutil.NewEnv(t)
	caRow, prof := newTestProfile(t, env, "renewal")
	if err := env.DB.Model(&prof).Updates(map[string]interface{}{"renewal_mail": 1, "renewal_mail_days": "14,7,1"}).Error; err != nil {
		t.Fatal(err)
	}
	expiring := func(cn string, in time.Duration, alerted string) {
		row := insertCertRow(t, env, caRow, prof, cn, cn)
		env.DB.Model(&row).Updates(map[string]interface{}{"valid_until": time.Now().Add(in), "alerted_days": alerted})
	}
	expiring("soon", 12*time.Hour, "")
	expiring("partial", 6*24*time.Hour, "7")
	expiring("far", 60*24*time.Hour, "")
	expiring("expired", -time.Hour, "")

	var mailed []string
	defer models.SetRenewalMailer(func(_ context.Context, cert models.Cert, _ models.Profile) (types.Info, error) {
		mailed = append(mailed, cert.Cn)
		return types.Info{}, nil
	})()

	check := models.Cert{DB: env.DB, Ctx: env.Ctx}
	if _, err := check.CheckRenewal(nil); err != nil {
		t.Fatal(err)
	}
	if len(mailed) != 1 || mailed[0] != "soon" {
		t.Fatalf("mailed %v, want [soon]", mailed)
	}
	var soon models.Cert
	env.DB.Where("cn = ?", "soon").First(&soon)
	if soon.AlertedDays != "1,7,14" {
		t.Errorf("alerted_days = %q, want every threshold marked", soon.AlertedDays)
	}
	var n int64
	env.DB.Model(&models.Cert{}).Where("cn = ?", "expired").Count(&n)
	if n != 0 {
		t.Errorf("the expired certificate was not revoked")
	}

	mailed = nil
	if _, err := check.CheckRenewal(nil); err != nil {
		t.Fatal(err)
	}
	if len(mailed) != 0 {
		t.Fatalf("second run mailed %v", mailed)
	}
}

// Resign starts a new validity window: its renewal mails are due again.
func TestResign_ResetsRenewalMailState(t *testing.T) {
	env := testutil.NewEnv(t)
	_, prof := newTestProfile(t, env, "resign-alert")
	leaf := models.Cert{DB: env.DB, Ctx: env.Ctx, Cn: "leaf", ProfileID: prof.ID}
	info, err := leaf.New()
	if err != nil {
		t.Fatal(err)
	}
	row := info.Entries.([]models.Cert)[0]
	env.DB.Model(&models.Cert{}).Where("id = ?", row.ID).Updates(map[string]interface{}{"alert": true, "alerted_days": "14,7"})

	if _, err := (models.Cert{DB: env.DB, Ctx: env.Ctx}).Resign(map[string]string{"id": itoaUint(row.ID)}); err != nil {
		t.Fatalf("Resign: %v", err)
	}
	var stored models.Cert
	env.DB.First(&stored, row.ID)
	if (stored.Alert != nil && *stored.Alert) || stored.AlertedDays != "" {
		t.Errorf("after resign alert=%v alerted_days=%q", stored.Alert, stored.AlertedDays)
	}
}
