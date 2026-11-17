package ocspresponder_test

import (
	"crypto"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"io"
	"sync/atomic"
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/ocspresponder"
	xocsp "golang.org/x/crypto/ocsp"
	"gorm.io/gorm"
)

// flakySigner fails while *fail is set, like a key whose token session
// is gone.
type flakySigner struct {
	crypto.Signer
	fail *atomic.Bool
}

func (s flakySigner) Sign(r io.Reader, digest []byte, opts crypto.SignerOpts) ([]byte, error) {
	if s.fail.Load() {
		return nil, errors.New("pkcs11: 0xB3: CKR_SESSION_HANDLE_INVALID")
	}
	return s.Signer.Sign(r, digest, opts)
}

// The key of a CA held in an HSM is looked up once and then cached; when
// it fails to sign, the responder looks it up again, so a lost session
// doesn't break OCSP until pfpki restarts.
func TestOCSP_HSMKeyCached(t *testing.T) {
	env := testutil.NewEnv(t)

	kt := certutils.KEY_ECDSA
	keyUsage, extKeyUsage := "32|64", "1|2"
	caInfo, err := models.CA{Cn: "ocsp-hsm-ca", KeyType: &kt, KeySize: 256, Digest: x509.ECDSAWithSHA256,
		KeyUsage: &keyUsage, ExtendedKeyUsage: &extKeyUsage, Days: 365, DB: env.DB, Ctx: env.Ctx}.New()
	if err != nil {
		t.Fatalf("CA.New: %v", err)
	}
	ca := caInfo.Entries.([]models.CA)[0]
	pair, err := tls.X509KeyPair([]byte(ca.Cert), []byte(ca.Key))
	if err != nil {
		t.Fatal(err)
	}
	caCert, _ := x509.ParseCertificate(pair.Certificate[0])
	// Present the CA as held in an HSM; the fake lookup returns its key.
	if err := env.DB.Model(&models.CA{}).Where("id = ?", ca.ID).Updates(map[string]interface{}{"hsm_id": 1, "hsm_key_id": "01"}).Error; err != nil {
		t.Fatal(err)
	}

	leafKU, leafEKU := "1|4", "2"
	pInfo, err := models.Profile{Name: "ocsp-hsm-prof", CaID: ca.ID, Validity: 30, KeyType: &kt, KeySize: 256,
		Digest: x509.ECDSAWithSHA256, KeyUsage: &leafKU, ExtendedKeyUsage: &leafEKU, DB: env.DB, Ctx: env.Ctx}.New()
	if err != nil {
		t.Fatalf("Profile.New: %v", err)
	}
	prof := pInfo.Entries.([]models.Profile)[0]

	var lookups atomic.Int32
	var failing atomic.Bool
	defer ocspresponder.SetHSMKeyPair(func(c models.CA, _ *gorm.DB) (*x509.Certificate, crypto.Signer, error) {
		lookups.Add(1)
		return caCert, flakySigner{Signer: pair.PrivateKey.(crypto.Signer), fail: &failing}, nil
	})()

	// Issuing the leaf signs with the (real, software) CA key: the CA
	// row is only marked as HSM for the responder.
	env.DB.Model(&models.CA{}).Where("id = ?", ca.ID).Update("hsm_id", 0)
	cInfo, err := models.Cert{Cn: "ocsp-hsm-leaf", ProfileID: prof.ID, DB: env.DB, Ctx: env.Ctx}.New()
	if err != nil {
		t.Fatalf("Cert.New: %v", err)
	}
	env.DB.Model(&models.CA{}).Where("id = ?", ca.ID).Update("hsm_id", 1)
	leafPair, err := tls.X509KeyPair([]byte(cInfo.Entries.([]models.Cert)[0].Cert), []byte(cInfo.Entries.([]models.Cert)[0].Key))
	if err != nil {
		t.Fatal(err)
	}
	leaf, _ := x509.ParseCertificate(leafPair.Certificate[0])
	req, err := xocsp.CreateRequest(leaf, caCert, nil)
	if err != nil {
		t.Fatal(err)
	}

	verify := func() {
		t.Helper()
		r := &ocspresponder.OCSPResponder{Handler: env.Handler}
		raw, err := r.Verify(req)
		if err != nil {
			t.Fatalf("Verify: %v", err)
		}
		resp, err := xocsp.ParseResponseForCert(raw, leaf, caCert)
		if err != nil {
			t.Fatalf("parse response: %v", err)
		}
		if resp.Status != xocsp.Good {
			t.Fatalf("status %d, want Good", resp.Status)
		}
	}

	verify()
	verify()
	verify()
	if n := lookups.Load(); n != 1 {
		t.Fatalf("%d HSM key lookups for 3 requests, want 1", n)
	}

	// The session is lost: the cached key fails once, the responder looks
	// it up again and answers.
	failing.Store(true)
	defer ocspresponder.SetHSMKeyPair(func(c models.CA, _ *gorm.DB) (*x509.Certificate, crypto.Signer, error) {
		lookups.Add(1)
		failing.Store(false)
		return caCert, flakySigner{Signer: pair.PrivateKey.(crypto.Signer), fail: &failing}, nil
	})()
	verify()
	if n := lookups.Load(); n != 2 {
		t.Fatalf("%d HSM key lookups after a failed signature, want 2", n)
	}
	verify()
	if n := lookups.Load(); n != 2 {
		t.Fatalf("%d HSM key lookups, want the new key cached", n)
	}
}
