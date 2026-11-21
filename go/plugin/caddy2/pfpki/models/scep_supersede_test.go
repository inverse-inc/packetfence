package models_test

import (
	"context"
	"crypto/x509"
	"strings"
	"testing"

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
