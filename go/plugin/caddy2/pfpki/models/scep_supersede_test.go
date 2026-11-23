package models_test

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/pem"
	"math/big"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"golang.org/x/crypto/ocsp"
)

// validatedCloud stands in for an Intune client whose ValidateRequest
// already passed: on the SCEP path the depot only carries a client for
// requests that got through the verifier middleware.
type validatedCloud struct{}

func (validatedCloud) NewCloud(context.Context, string) error        { return nil }
func (validatedCloud) ValidateRequest(context.Context, []byte) error { return nil }
func (validatedCloud) SuccessReply(context.Context, *x509.Certificate, []byte, string) error {
	return nil
}
func (validatedCloud) FailureReply(context.Context, *x509.Certificate, []byte, string) error {
	return nil
}

func countCN(t *testing.T, env *testutil.Env, cn string) (live, revoked int64, reason int) {
	t.Helper()
	if err := env.DB.Model(&models.Cert{}).Where("cn = ?", cn).Count(&live).Error; err != nil {
		t.Fatal(err)
	}
	var rows []models.RevokedCert
	if err := env.DB.Where("cn = ?", cn).Find(&rows).Error; err != nil {
		t.Fatal(err)
	}
	revoked = int64(len(rows))
	if revoked > 0 {
		reason = rows[0].CRLReason
	}
	return
}

// TestHasCN_CloudValidatedReissueSupersedes covers the Intune reissue
// flow (GitHub #7356): Intune revokes the device's certificate in its
// own queue and re-enrolls it seconds later, before the queue can be
// processed. A SCEP request that Intune validated must therefore
// supersede the existing certificate for the same CN, while the same
// request without Intune validation, or on a non-cloud profile, is
// still refused as a duplicate.
func TestHasCN_CloudValidatedReissueSupersedes(t *testing.T) {
	env := testutil.NewEnv(t)
	caRow := mustCreateCA(t, env, "intune-ca", certutils.KEY_RSA, 2048, x509.SHA256WithRSA)

	newProfile := func(name string, cloud int) models.Profile {
		p := profileTemplate(name, caRow, certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
		p.CloudEnabled = cloud
		p.CloudService = "intune-test"
		p.DaysBeforeRenewal = 14
		p.DB, p.Ctx = env.DB, env.Ctx
		pinfo, err := p.New()
		if err != nil {
			t.Fatalf("Profile.New(%s): %v", name, err)
		}
		return pinfo.Entries.([]models.Profile)[0]
	}
	issue := func(prof models.Profile, cn string) {
		leaf := models.Cert{DB: env.DB, Ctx: env.Ctx, Cn: cn, Mail: "dev@example.test", ProfileID: prof.ID}
		if _, err := leaf.New(); err != nil {
			t.Fatalf("Cert.New(%s): %v", cn, err)
		}
	}

	cloudProf := newProfile("intune-prof", 1)
	issue(cloudProf, "device-1")
	depot := models.CA{DB: env.DB, Ctx: env.Ctx}

	// Same CN, request not validated by Intune (no client on the depot):
	// refused, nothing revoked.
	if _, err := depot.HasCN("device-1", 14, nil, false, cloudProf.Name); err == nil || !strings.Contains(err.Error(), "already exist") {
		t.Fatalf("unvalidated duplicate: got err=%v, want 'already exist'", err)
	}
	if live, revoked, _ := countCN(t, env, "device-1"); live != 1 || revoked != 0 {
		t.Fatalf("after refusal: live=%d revoked=%d", live, revoked)
	}

	// Same CN, Intune-validated: the existing certificate is superseded
	// and issuance is allowed.
	depot.Cloud = validatedCloud{}
	ok, err := depot.HasCN("device-1", 14, nil, false, cloudProf.Name)
	if err != nil || !ok {
		t.Fatalf("validated re-enrollment: ok=%v err=%v", ok, err)
	}
	live, revoked, reason := countCN(t, env, "device-1")
	if live != 0 || revoked != 1 || reason != ocsp.Superseded {
		t.Fatalf("after supersede: live=%d revoked=%d reason=%d", live, revoked, reason)
	}
	// And the same again with nothing live is simply allowed.
	if ok, err := depot.HasCN("device-1", 14, nil, false, cloudProf.Name); err != nil || !ok {
		t.Fatalf("second validated call: ok=%v err=%v", ok, err)
	}

	// A profile without a cloud service never supersedes, whatever the
	// depot carries.
	plainProf := newProfile("plain-prof", 0)
	issue(plainProf, "device-2")
	if _, err := depot.HasCN("device-2", 14, nil, false, plainProf.Name); err == nil || !strings.Contains(err.Error(), "already exist") {
		t.Fatalf("non-cloud profile: got err=%v, want 'already exist'", err)
	}
	if live, revoked, _ := countCN(t, env, "device-2"); live != 1 || revoked != 0 {
		t.Fatalf("non-cloud profile touched certs: live=%d revoked=%d", live, revoked)
	}
}

// withIntuneDeviceID returns a self-signed certificate carrying the
// Intune device ID SAN (IntuneDeviceId://<id>), or none when id is "".
func withIntuneDeviceID(t *testing.T, id string) (*x509.Certificate, string) {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	tmpl := &x509.Certificate{SerialNumber: big.NewInt(1), NotBefore: time.Now(), NotAfter: time.Now().AddDate(1, 0, 0)}
	if id != "" {
		u, _ := url.Parse("IntuneDeviceId://" + id)
		tmpl.URIs = []*url.URL{u}
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	cert, _ := x509.ParseCertificate(der)
	return cert, string(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}))
}

// TestHasCN_CloudReissueKeepsOtherDevices: a cloud-validated
// re-enrollment only supersedes what it replaces. With the Intune device
// ID SAN, only the certificate of the same device; without it, the
// oldest certificates needed to make room under the duplicate limit.
func TestHasCN_CloudReissueKeepsOtherDevices(t *testing.T) {
	env := testutil.NewEnv(t)
	caRow := mustCreateCA(t, env, "intune-dev-ca", certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
	newProfile := func(name string, allowDup, maxDup int) models.Profile {
		p := profileTemplate(name, caRow, certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
		p.CloudEnabled = 1
		p.CloudService = "intune-test"
		p.DaysBeforeRenewal = 14
		p.AllowDuplicatedCN = allowDup
		p.MaximumDuplicatedCN = maxDup
		p.DB, p.Ctx = env.DB, env.Ctx
		pinfo, err := p.New()
		if err != nil {
			t.Fatalf("Profile.New(%s): %v", name, err)
		}
		return pinfo.Entries.([]models.Profile)[0]
	}
	// issue creates a certificate for cn and stores pemCert as its
	// certificate when given, so it carries that device ID.
	issue := func(prof models.Profile, cn, pemCert string) uint {
		t.Helper()
		leaf := models.Cert{DB: env.DB, Ctx: env.Ctx, Cn: cn, Mail: "dev@example.test", ProfileID: prof.ID}
		if _, err := leaf.New(); err != nil {
			t.Fatalf("Cert.New(%s): %v", cn, err)
		}
		var row models.Cert
		if err := env.DB.Where("cn = ?", cn).Order("id desc").First(&row).Error; err != nil {
			t.Fatal(err)
		}
		if pemCert != "" {
			if err := env.DB.Model(&models.Cert{}).Where("id = ?", row.ID).Update("cert", pemCert).Error; err != nil {
				t.Fatal(err)
			}
		}
		return row.ID
	}
	depot := models.CA{DB: env.DB, Ctx: env.Ctx, Cloud: validatedCloud{}}

	t.Run("duplicates off, another device", func(t *testing.T) {
		prof := newProfile("intune-off-other", 0, 0)
		_, pemA := withIntuneDeviceID(t, "aaaa-1111")
		issue(prof, "user-1", pemA)
		newB, _ := withIntuneDeviceID(t, "bbbb-2222")
		if _, err := depot.HasCN("user-1", 14, newB, false, prof.Name); err == nil || !strings.Contains(err.Error(), "already exist") {
			t.Fatalf("other device: got err=%v, want 'already exist'", err)
		}
		if live, revoked, _ := countCN(t, env, "user-1"); live != 1 || revoked != 0 {
			t.Fatalf("other device's cert touched: live=%d revoked=%d", live, revoked)
		}
	})

	t.Run("duplicates off, same device", func(t *testing.T) {
		prof := newProfile("intune-off-same", 0, 0)
		_, pemA := withIntuneDeviceID(t, "AAAA-1111")
		issue(prof, "user-2", pemA)
		newA, _ := withIntuneDeviceID(t, "aaaa-1111")
		if ok, err := depot.HasCN("user-2", 14, newA, false, prof.Name); err != nil || !ok {
			t.Fatalf("same device: ok=%v err=%v", ok, err)
		}
		if live, revoked, reason := countCN(t, env, "user-2"); live != 0 || revoked != 1 || reason != ocsp.Superseded {
			t.Fatalf("same device: live=%d revoked=%d reason=%d", live, revoked, reason)
		}
	})

	t.Run("duplicates allowed, no device ID", func(t *testing.T) {
		prof := newProfile("intune-max3", 1, 3)
		first := issue(prof, "user-3", "")
		issue(prof, "user-3", "")
		issue(prof, "user-3", "")
		if ok, err := depot.HasCN("user-3", 14, nil, false, prof.Name); err != nil || !ok {
			t.Fatalf("4th device: ok=%v err=%v", ok, err)
		}
		if live, revoked, _ := countCN(t, env, "user-3"); live != 2 || revoked != 1 {
			t.Fatalf("4th device: live=%d revoked=%d, want only the oldest revoked", live, revoked)
		}
		var gone models.Cert
		if err := env.DB.Where("id = ?", first).Find(&gone).Error; err != nil || gone.ID != 0 {
			t.Fatalf("the oldest certificate (id %d) is still live", first)
		}
	})

	t.Run("duplicates allowed, other devices kept", func(t *testing.T) {
		prof := newProfile("intune-max2", 1, 2)
		_, pemA := withIntuneDeviceID(t, "aaaa-1111")
		_, pemB := withIntuneDeviceID(t, "bbbb-2222")
		issue(prof, "user-4", pemA)
		issue(prof, "user-4", pemB)
		newC, _ := withIntuneDeviceID(t, "cccc-3333")
		if _, err := depot.HasCN("user-4", 14, newC, false, prof.Name); err == nil || !strings.Contains(err.Error(), "already exist") {
			t.Fatalf("3rd device over the limit: got err=%v, want 'already exist'", err)
		}
		if live, revoked, _ := countCN(t, env, "user-4"); live != 2 || revoked != 0 {
			t.Fatalf("other devices' certs touched: live=%d revoked=%d", live, revoked)
		}
	})
}
