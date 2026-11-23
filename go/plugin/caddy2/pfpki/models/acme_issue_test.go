package models_test

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"errors"
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"golang.org/x/crypto/ocsp"
)

// TestIssueACMECert_DuplicateCNPolicy covers the ACME issuance under the
// duplicate-CN policy of the template: the revocation of the superseded
// certs follows the same policy as the check, a refusal revokes nothing,
// and a failed signing leaves the existing cert live.
func TestIssueACMECert_DuplicateCNPolicy(t *testing.T) {
	env := testutil.NewEnv(t)
	caRow := mustCreateCA(t, env, "acme-dup-ca", certutils.KEY_RSA, 2048, x509.SHA256WithRSA)

	newProfile := func(name string, allowDup, maxDup, daysBeforeRenewal int) models.Profile {
		p := profileTemplate(name, caRow, certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
		p.AllowDuplicatedCN = allowDup
		p.MaximumDuplicatedCN = maxDup
		p.DB, p.Ctx = env.DB, env.Ctx
		pinfo, err := p.New()
		if err != nil {
			t.Fatalf("Profile.New(%s): %v", name, err)
		}
		prof := pinfo.Entries.([]models.Profile)[0]
		// Profile.New keeps the default when given 0.
		if err := env.DB.Model(&models.Profile{}).Where("id = ?", prof.ID).Update("days_before_renewal", daysBeforeRenewal).Error; err != nil {
			t.Fatal(err)
		}
		var loaded models.Profile
		if err := env.DB.Preload("Ca").First(&loaded, prof.ID).Error; err != nil {
			t.Fatal(err)
		}
		return loaded
	}
	issue := func(prof models.Profile, cn string) {
		t.Helper()
		leaf := models.Cert{DB: env.DB, Ctx: env.Ctx, Cn: cn, Mail: "dev@example.test", ProfileID: prof.ID}
		if _, err := leaf.New(); err != nil {
			t.Fatalf("Cert.New(%s): %v", cn, err)
		}
	}
	csrFor := func(cn string) []byte {
		t.Helper()
		key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
		if err != nil {
			t.Fatal(err)
		}
		der, err := x509.CreateCertificateRequest(rand.Reader, &x509.CertificateRequest{Subject: pkix.Name{CommonName: cn}, DNSNames: []string{cn}}, key)
		if err != nil {
			t.Fatal(err)
		}
		return der
	}
	ids := func(cn string) []models.AcmeIdentifier { return []models.AcmeIdentifier{{Type: "dns", Value: cn}} }

	t.Run("unlimited duplicates revoke nothing", func(t *testing.T) {
		prof := newProfile("acme-unlimited", 1, 0, 0)
		cn := "unlimited.example.test"
		issue(prof, cn)
		issue(prof, cn)
		if _, err := models.IssueACMECert(env.DB, env.Ctx, prof, csrFor(cn), ids(cn), 0, cn); err != nil {
			t.Fatalf("IssueACMECert: %v", err)
		}
		if live, revoked, _ := countCN(t, env, cn); live != 3 || revoked != 0 {
			t.Fatalf("live=%d revoked=%d, want 3 live and none revoked", live, revoked)
		}
	})

	t.Run("refusal revokes nothing", func(t *testing.T) {
		prof := newProfile("acme-refuse", 0, 0, 14)
		cn := "refuse.example.test"
		issue(prof, cn)
		_, err := models.IssueACMECert(env.DB, env.Ctx, prof, csrFor(cn), ids(cn), 0, cn)
		if !errors.Is(err, models.ErrACMEDuplicateCN) {
			t.Fatalf("got err=%v, want ErrACMEDuplicateCN", err)
		}
		if live, revoked, _ := countCN(t, env, cn); live != 1 || revoked != 0 {
			t.Fatalf("live=%d revoked=%d, want the existing cert live", live, revoked)
		}
	})

	t.Run("supersede after issuance", func(t *testing.T) {
		prof := newProfile("acme-supersede", 0, 0, 0)
		cn := "supersede.example.test"
		issue(prof, cn)
		cert, err := models.IssueACMECert(env.DB, env.Ctx, prof, csrFor(cn), ids(cn), 0, cn)
		if err != nil {
			t.Fatalf("IssueACMECert: %v", err)
		}
		live, revoked, reason := countCN(t, env, cn)
		if live != 1 || revoked != 1 || reason != ocsp.Superseded {
			t.Fatalf("live=%d revoked=%d reason=%d, want the old cert superseded", live, revoked, reason)
		}
		var left models.Cert
		if err := env.DB.Where("cn = ?", cn).First(&left).Error; err != nil || left.ID != cert.ID {
			t.Fatalf("live cert id=%d err=%v, want the new cert %d", left.ID, err, cert.ID)
		}
	})

	t.Run("failed signing revokes nothing", func(t *testing.T) {
		prof := newProfile("acme-sign-fails", 0, 0, 0)
		cn := "signfails.example.test"
		issue(prof, cn)
		broken := prof
		broken.Ca.Key = "not a key"
		if _, err := models.IssueACMECert(env.DB, env.Ctx, broken, csrFor(cn), ids(cn), 0, cn); err == nil {
			t.Fatal("IssueACMECert with a broken CA key succeeded")
		}
		if live, revoked, _ := countCN(t, env, cn); live != 1 || revoked != 0 {
			t.Fatalf("live=%d revoked=%d, want the existing cert live", live, revoked)
		}
	})
}
