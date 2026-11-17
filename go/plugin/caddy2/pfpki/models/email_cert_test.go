package models_test

import (
	"context"
	"crypto/x509"
	"fmt"
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

// The e-mailed .p12 comes with its password only when the profile's
// p12_mail_password switch is on; the API answer always carries it, so
// the admin can hand it over otherwise.
func TestCertEmail_HonoursP12MailPassword(t *testing.T) {
	env := testutil.NewEnv(t)
	ca := mustCreateCA(t, env, "mail-ca", certutils.KEY_ECDSA, 256, x509.ECDSAWithSHA256)
	p := profileTemplate("mail-prof", ca, certutils.KEY_ECDSA, 256, x509.ECDSAWithSHA256)
	p.DB, p.Ctx = env.DB, env.Ctx
	pinfo, err := p.New()
	if err != nil {
		t.Fatalf("Profile.New: %v", err)
	}
	profile := pinfo.Entries.([]models.Profile)[0]
	leaf := models.Cert{DB: env.DB, Ctx: env.Ctx, Cn: "mail-leaf", Mail: "user@example.test", ProfileID: profile.ID}
	cinfo, err := leaf.New()
	if err != nil {
		t.Fatalf("Cert.New: %v", err)
	}
	id := fmt.Sprint(cinfo.Entries.([]models.Cert)[0].ID)

	var mailed *string
	restore := models.SetCertMailer(func(_ context.Context, _ models.Cert, _ models.Profile, file []byte, password string) (types.Info, error) {
		if len(file) == 0 {
			t.Errorf("no .p12 attached")
		}
		mailed = &password
		return types.Info{}, nil
	})
	defer restore()

	for _, c := range []struct {
		name       string
		switchOn   int
		params     map[string]string
		wantMailed bool
	}{
		{"switch off, generated", 0, map[string]string{"id": id}, false},
		{"switch off, admin password", 0, map[string]string{"id": id, "mail_password": "adm1n-pass"}, false},
		{"switch on, generated", 1, map[string]string{"id": id}, true},
		{"switch on, admin password", 1, map[string]string{"id": id, "mail_password": "adm1n-pass"}, true},
	} {
		t.Run(c.name, func(t *testing.T) {
			if err := env.DB.Model(&models.Profile{}).Where("id = ?", profile.ID).Update("p12_mail_password", c.switchOn).Error; err != nil {
				t.Fatal(err)
			}
			mailed = nil
			info, err := models.Cert{DB: env.DB, Ctx: env.Ctx}.Download(c.params)
			if err != nil {
				t.Fatalf("Download: %v", err)
			}
			if mailed == nil {
				t.Fatalf("nothing mailed")
			}
			if info.Password == "" {
				t.Errorf("the API answer has no password")
			}
			if pw, ok := c.params["mail_password"]; ok && info.Password != pw {
				t.Errorf("password %q, want the admin's %q", info.Password, pw)
			}
			if c.wantMailed {
				if *mailed != info.Password || !info.PasswordMailed {
					t.Errorf("mailed password %q (password_mailed=%v), want %q", *mailed, info.PasswordMailed, info.Password)
				}
			} else if *mailed != "" || info.PasswordMailed {
				t.Errorf("mailed password %q (password_mailed=%v) with p12_mail_password off", *mailed, info.PasswordMailed)
			}
		})
	}
}
