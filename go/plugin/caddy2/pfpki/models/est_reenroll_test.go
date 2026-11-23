package models_test

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"errors"
	"math/big"
	"strings"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"golang.org/x/crypto/ocsp"
)

// TestIssueESTCert_Reenroll: a simplereenroll renews the live
// certificate of its key and revokes it, and refuses a certificate that
// has expired (simpleenroll is for that).
func TestIssueESTCert_Reenroll(t *testing.T) {
	env := testutil.NewEnv(t)
	caRow := mustCreateCA(t, env, "est-reenroll-ca", certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
	p := profileTemplate("est-reenroll-prof", caRow, certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
	p.DB, p.Ctx = env.DB, env.Ctx
	pinfo, err := p.New()
	if err != nil {
		t.Fatalf("Profile.New: %v", err)
	}
	var prof models.Profile
	if err := env.DB.Preload("Ca").First(&prof, pinfo.Entries.([]models.Profile)[0].ID).Error; err != nil {
		t.Fatal(err)
	}

	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	csr := func(cn string) *x509.CertificateRequest {
		der, err := x509.CreateCertificateRequest(rand.Reader, &x509.CertificateRequest{Subject: pkix.Name{CommonName: cn}}, key)
		if err != nil {
			t.Fatal(err)
		}
		c, err := x509.ParseCertificateRequest(der)
		if err != nil {
			t.Fatal(err)
		}
		return c
	}

	const cn = "est-device-1"
	if _, err := models.IssueESTCert(env.DB, env.Ctx, prof, csr(cn), false); err != nil {
		t.Fatalf("simpleenroll: %v", err)
	}
	renewed, err := models.IssueESTCert(env.DB, env.Ctx, prof, csr(cn), true)
	if err != nil {
		t.Fatalf("simplereenroll: %v", err)
	}
	live, revoked, reason := countCN(t, env, cn)
	if live != 1 || revoked != 1 || reason != ocsp.Superseded {
		t.Fatalf("after re-enrollment: live=%d revoked=%d reason=%d", live, revoked, reason)
	}

	// The live certificate expires: a re-enrollment is refused.
	tmpl := &x509.Certificate{SerialNumber: big.NewInt(7), Subject: pkix.Name{CommonName: cn},
		NotBefore: time.Now().AddDate(0, 0, -30), NotAfter: time.Now().AddDate(0, 0, -1)}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	expired := string(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}))
	if err := env.DB.Model(&models.Cert{}).Where("id = ?", renewed.ID).Update("cert", expired).Error; err != nil {
		t.Fatal(err)
	}
	_, err = models.IssueESTCert(env.DB, env.Ctx, prof, csr(cn), true)
	if !errors.Is(err, models.ErrESTPolicy) || !strings.Contains(err.Error(), "has expired") {
		t.Fatalf("re-enrollment of an expired certificate: err=%v, want an ErrESTPolicy 'has expired'", err)
	}
	if live, revoked, _ := countCN(t, env, cn); live != 1 || revoked != 1 {
		t.Fatalf("after the refusal: live=%d revoked=%d, want nothing changed", live, revoked)
	}
}
