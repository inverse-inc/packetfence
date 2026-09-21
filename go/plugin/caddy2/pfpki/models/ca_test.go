package models_test

import (
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

// caTemplate returns a CA struct primed with the boilerplate fields every
// case shares; tests then override KeyType/KeySize/Digest.
func caTemplate(cn string, kt types.Type, size int, digest x509.SignatureAlgorithm) models.CA {
	keyUsage := "32|64"          // CertSign|CRLSign
	extKeyUsage := "1|2"         // ServerAuth|ClientAuth
	return models.CA{
		Cn:                 cn,
		Mail:               "ca@example.test",
		Organisation:       "Acme",
		OrganisationalUnit: "Eng",
		Country:            "US",
		KeyType:            &kt,
		KeySize:            size,
		Digest:             digest,
		KeyUsage:           &keyUsage,
		ExtendedKeyUsage:   &extKeyUsage,
		Days:               365,
	}
}

// parseCAEntry asserts that Information.Entries holds a slice with one CA
// whose Cert column parses to a self-signed x509 certificate, and returns it.
func parseCAEntry(t *testing.T, info types.Info) *x509.Certificate {
	t.Helper()
	cas, ok := info.Entries.([]models.CA)
	if !ok {
		t.Fatalf("Entries is %T, want []models.CA", info.Entries)
	}
	if len(cas) != 1 {
		t.Fatalf("len(Entries)=%d, want 1", len(cas))
	}
	block, _ := pem.Decode([]byte(cas[0].Cert))
	if block == nil {
		t.Fatalf("CA Cert column is not PEM:\n%s", cas[0].Cert)
	}
	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		t.Fatalf("parse CA cert: %v", err)
	}
	if !cert.IsCA {
		t.Fatalf("generated cert is not a CA")
	}
	return cert
}

func TestCA_New_AllKeyAndDigestCombos(t *testing.T) {
	type tc struct {
		name      string
		keyType   types.Type
		keySize   int
		digest    x509.SignatureAlgorithm
		wantSigOK func(*x509.Certificate) bool
	}

	wantSig := func(want x509.SignatureAlgorithm) func(*x509.Certificate) bool {
		return func(c *x509.Certificate) bool { return c.SignatureAlgorithm == want }
	}

	cases := []tc{
		// --- RSA ---
		{"RSA-2048+SHA256WithRSA", certutils.KEY_RSA, 2048, x509.SHA256WithRSA, wantSig(x509.SHA256WithRSA)},
		{"RSA-2048+SHA384WithRSA", certutils.KEY_RSA, 2048, x509.SHA384WithRSA, wantSig(x509.SHA384WithRSA)},
		{"RSA-2048+SHA512WithRSA", certutils.KEY_RSA, 2048, x509.SHA512WithRSA, wantSig(x509.SHA512WithRSA)},
		{"RSA-2048+SHA1WithRSA", certutils.KEY_RSA, 2048, x509.SHA1WithRSA, wantSig(x509.SHA1WithRSA)},
		{"RSA-3072+SHA256WithRSA", certutils.KEY_RSA, 3072, x509.SHA256WithRSA, wantSig(x509.SHA256WithRSA)},
		{"RSA-4096+SHA256WithRSA", certutils.KEY_RSA, 4096, x509.SHA256WithRSA, wantSig(x509.SHA256WithRSA)},
		{"RSA-2048+SHA256WithRSAPSS", certutils.KEY_RSA, 2048, x509.SHA256WithRSAPSS, wantSig(x509.SHA256WithRSAPSS)},
		{"RSA-2048+SHA384WithRSAPSS", certutils.KEY_RSA, 2048, x509.SHA384WithRSAPSS, wantSig(x509.SHA384WithRSAPSS)},
		{"RSA-2048+SHA512WithRSAPSS", certutils.KEY_RSA, 2048, x509.SHA512WithRSAPSS, wantSig(x509.SHA512WithRSAPSS)},

		// --- ECDSA ---
		{"ECDSA-P256+SHA256", certutils.KEY_ECDSA, 256, x509.ECDSAWithSHA256, wantSig(x509.ECDSAWithSHA256)},
		{"ECDSA-P384+SHA384", certutils.KEY_ECDSA, 384, x509.ECDSAWithSHA384, wantSig(x509.ECDSAWithSHA384)},
		{"ECDSA-P521+SHA512", certutils.KEY_ECDSA, 521, x509.ECDSAWithSHA512, wantSig(x509.ECDSAWithSHA512)},
		{"ECDSA-P256+SHA1", certutils.KEY_ECDSA, 256, x509.ECDSAWithSHA1, wantSig(x509.ECDSAWithSHA1)},

		// --- Ed25519 ---
		{"Ed25519+PureEd25519", certutils.KEY_ED25519, 0, x509.PureEd25519, wantSig(x509.PureEd25519)},

		// --- CompatibleSigAlgo fallback: mismatched digest gets defaulted ---
		{
			name:      "ECDSA-P384 with bogus RSA digest -> default ECDSA-SHA384",
			keyType:   certutils.KEY_ECDSA,
			keySize:   384,
			digest:    x509.SHA256WithRSA, // intentionally incompatible
			wantSigOK: func(c *x509.Certificate) bool { return c.SignatureAlgorithm == x509.ECDSAWithSHA384 },
		},
	}

	env := testutil.NewEnv(t)

	for i, c := range cases {
		c := c
		t.Run(c.name, func(t *testing.T) {
			cn := fmt.Sprintf("ca-%d-%s", i, strings.ReplaceAll(c.name, " ", "_"))
			m := caTemplate(cn, c.keyType, c.keySize, c.digest)
			m.DB = env.DB
			m.Ctx = env.Ctx

			info, err := m.New()
			if err != nil {
				t.Fatalf("CA.New: %v (info=%+v)", err, info)
			}

			cert := parseCAEntry(t, info)

			if !c.wantSigOK(cert) {
				t.Errorf("got SignatureAlgorithm=%v", cert.SignatureAlgorithm)
			}
			if cert.Subject.CommonName != cn {
				t.Errorf("CN mismatch: got %q want %q", cert.Subject.CommonName, cn)
			}
			if !cert.NotAfter.After(time.Now()) {
				t.Errorf("NotAfter %v is not in the future", cert.NotAfter)
			}

			// CA must self-verify.
			roots := x509.NewCertPool()
			roots.AddCert(cert)
			if _, err := cert.Verify(x509.VerifyOptions{
				Roots:     roots,
				KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageAny},
			}); err != nil {
				t.Errorf("self-verify: %v", err)
			}
		})
	}
}

// TestCA_New_RejectsBadSize confirms that invalid key sizes are surfaced as
// errors rather than producing a malformed CA.
func TestCA_New_RejectsBadSize(t *testing.T) {
	env := testutil.NewEnv(t)

	cases := []struct {
		name    string
		keyType types.Type
		size    int
	}{
		{"RSA too small", certutils.KEY_RSA, 1024},
		{"ECDSA bad curve", certutils.KEY_ECDSA, 999},
	}

	for _, c := range cases {
		c := c
		t.Run(c.name, func(t *testing.T) {
			m := caTemplate("badsize-"+c.name, c.keyType, c.size, x509.SHA256WithRSA)
			m.DB = env.DB
			m.Ctx = env.Ctx
			if _, err := m.New(); err == nil {
				t.Fatalf("expected error for %s/%d, got nil", c.name, c.size)
			}
		})
	}
}
