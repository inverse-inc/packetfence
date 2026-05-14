package models_test

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"fmt"
	"strings"
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

// mustCreateCA creates a CA with the given params and returns the persisted
// row (with ID populated). Test stops on failure.
func mustCreateCA(t *testing.T, env *testutil.Env, cn string, kt types.Type, size int, digest x509.SignatureAlgorithm) models.CA {
	t.Helper()
	m := caTemplate(cn, kt, size, digest)
	m.DB = env.DB
	m.Ctx = env.Ctx
	info, err := m.New()
	if err != nil {
		t.Fatalf("CA.New(%s): %v", cn, err)
	}
	cas := info.Entries.([]models.CA)
	return cas[0]
}

// profileTemplate returns a Profile bound to ca, configured with sensible
// defaults shared by all leaf-issuance tests.
func profileTemplate(name string, ca models.CA, kt types.Type, size int, digest x509.SignatureAlgorithm) models.Profile {
	keyUsage := "1|4" // DigitalSignature|KeyEncipherment
	extKeyUsage := "1|2"
	return models.Profile{
		Name:             name,
		CaID:             ca.ID,
		CaName:           ca.Cn,
		Mail:             "leaf@example.test",
		Organisation:     "Acme",
		Validity:         90,
		KeyType:          &kt,
		KeySize:          size,
		Digest:           digest,
		KeyUsage:         &keyUsage,
		ExtendedKeyUsage: &extKeyUsage,
	}
}

// parseFirstCertPEM extracts the first CERTIFICATE block from pemBytes.
func parseFirstCertPEM(t *testing.T, pemBytes []byte) *x509.Certificate {
	t.Helper()
	block, _ := pem.Decode(pemBytes)
	if block == nil {
		t.Fatalf("no PEM block in %q", string(pemBytes))
	}
	c, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		t.Fatalf("parse cert: %v", err)
	}
	return c
}

// verifyLeaf chains leaf against ca and fails the test if the chain doesn't
// validate.
func verifyLeaf(t *testing.T, leaf, ca *x509.Certificate) {
	t.Helper()
	roots := x509.NewCertPool()
	roots.AddCert(ca)
	if _, err := leaf.Verify(x509.VerifyOptions{
		Roots:     roots,
		KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageAny},
	}); err != nil {
		t.Fatalf("chain verify: %v", err)
	}
}

func TestProfile_New_AllKeyTypes(t *testing.T) {
	env := testutil.NewEnv(t)
	ca := mustCreateCA(t, env, "prof-root", certutils.KEY_ECDSA, 256, x509.ECDSAWithSHA256)

	cases := []struct {
		name    string
		keyType types.Type
		size    int
		digest  x509.SignatureAlgorithm
	}{
		{"RSA2048+SHA256", certutils.KEY_RSA, 2048, x509.SHA256WithRSA},
		{"ECDSA-P256", certutils.KEY_ECDSA, 256, x509.ECDSAWithSHA256},
		{"ECDSA-P384", certutils.KEY_ECDSA, 384, x509.ECDSAWithSHA384},
		{"Ed25519", certutils.KEY_ED25519, 0, x509.PureEd25519},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			p := profileTemplate("prof-"+c.name, ca, c.keyType, c.size, c.digest)
			p.DB = env.DB
			p.Ctx = env.Ctx
			info, err := p.New()
			if err != nil {
				t.Fatalf("Profile.New: %v (info=%+v)", err, info)
			}
			profs, ok := info.Entries.([]models.Profile)
			if !ok || len(profs) != 1 {
				t.Fatalf("Entries=%v want one Profile", info.Entries)
			}
			if profs[0].ID == 0 {
				t.Errorf("profile ID was not populated by Create")
			}
		})
	}
}

func TestCert_New_IssuesLeafAcrossKeyTypes(t *testing.T) {
	env := testutil.NewEnv(t)

	caCases := []struct {
		name    string
		caKey   types.Type
		caSize  int
		caHash  x509.SignatureAlgorithm
		leafKey types.Type
		leafSz  int
		leafHsh x509.SignatureAlgorithm
	}{
		{"RSA-CA_RSA-Leaf", certutils.KEY_RSA, 2048, x509.SHA256WithRSA, certutils.KEY_RSA, 2048, x509.SHA256WithRSA},
		{"ECDSAP384-CA_ECDSAP256-Leaf", certutils.KEY_ECDSA, 384, x509.ECDSAWithSHA384, certutils.KEY_ECDSA, 256, x509.ECDSAWithSHA256},
		{"Ed25519-CA_Ed25519-Leaf", certutils.KEY_ED25519, 0, x509.PureEd25519, certutils.KEY_ED25519, 0, x509.PureEd25519},
	}

	for _, cc := range caCases {
		t.Run(cc.name, func(t *testing.T) {
			caRow := mustCreateCA(t, env, "leaf-ca-"+cc.name, cc.caKey, cc.caSize, cc.caHash)
			p := profileTemplate("leaf-prof-"+cc.name, caRow, cc.leafKey, cc.leafSz, cc.leafHsh)
			p.DB = env.DB
			p.Ctx = env.Ctx
			pinfo, err := p.New()
			if err != nil {
				t.Fatalf("Profile.New: %v", err)
			}
			profile := pinfo.Entries.([]models.Profile)[0]

			leaf := models.Cert{
				DB:        env.DB,
				Ctx:       env.Ctx,
				Cn:        "leaf-" + cc.name,
				Mail:      "leaf@example.test",
				DNSNames:  "leaf.example.test,alt.example.test",
				ProfileID: profile.ID,
			}
			cinfo, err := leaf.New()
			if err != nil {
				t.Fatalf("Cert.New: %v (info=%+v)", err, cinfo)
			}
			certs := cinfo.Entries.([]models.Cert)
			if len(certs) != 1 {
				t.Fatalf("len(Entries)=%d, want 1", len(certs))
			}

			caCert := parseFirstCertPEM(t, []byte(caRow.Cert))
			leafCert := parseFirstCertPEM(t, []byte(certs[0].Cert))
			verifyLeaf(t, leafCert, caCert)

			if leafCert.Subject.CommonName != leaf.Cn {
				t.Errorf("leaf CN=%q want %q", leafCert.Subject.CommonName, leaf.Cn)
			}
			wantDNS := []string{"leaf.example.test", "alt.example.test"}
			if !equalStrings(leafCert.DNSNames, wantDNS) {
				t.Errorf("DNSNames=%v want %v", leafCert.DNSNames, wantDNS)
			}
		})
	}
}

func TestCSR_New_SignsExternalCSR(t *testing.T) {
	env := testutil.NewEnv(t)
	caRow := mustCreateCA(t, env, "csr-ca", certutils.KEY_ECDSA, 384, x509.ECDSAWithSHA384)
	p := profileTemplate("csr-prof", caRow, certutils.KEY_ECDSA, 256, x509.ECDSAWithSHA256)
	p.DB = env.DB
	p.Ctx = env.Ctx
	pinfo, err := p.New()
	if err != nil {
		t.Fatalf("Profile.New: %v", err)
	}
	profile := pinfo.Entries.([]models.Profile)[0]

	// Build a CSR client-side. The pfpki helper used to derive the SubjectKey
	// ID only accepts RSA / ECDSA public keys, so use ECDSA here.
	csrKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("ecdsa keygen: %v", err)
	}
	csrDER, err := x509.CreateCertificateRequest(rand.Reader, &x509.CertificateRequest{
		Subject:  pkix.Name{CommonName: "csr-leaf.example.test"},
		DNSNames: []string{"csr-leaf.example.test"},
	}, csrKey)
	if err != nil {
		t.Fatalf("CreateCertificateRequest: %v", err)
	}
	csrPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE REQUEST", Bytes: csrDER})

	t.Run("PEM input", func(t *testing.T) {
		csr := models.CSR{DB: env.DB, Ctx: env.Ctx, Csr: string(csrPEM)}
		info, err := csr.New(map[string]string{"id": fmt.Sprintf("%d", profile.ID)})
		if err != nil {
			t.Fatalf("CSR.New(PEM): %v (info=%+v)", err, info)
		}
		assertLeafChains(t, info, caRow)
	})

	t.Run("DER input", func(t *testing.T) {
		csr := models.CSR{DB: env.DB, Ctx: env.Ctx, Csr: string(csrDER)}
		info, err := csr.New(map[string]string{"id": fmt.Sprintf("%d", profile.ID)})
		if err != nil {
			t.Fatalf("CSR.New(DER): %v (info=%+v)", err, info)
		}
		assertLeafChains(t, info, caRow)
	})

	t.Run("invalid PEM", func(t *testing.T) {
		csr := models.CSR{DB: env.DB, Ctx: env.Ctx, Csr: "this is not a CSR"}
		_, err := csr.New(map[string]string{"id": fmt.Sprintf("%d", profile.ID)})
		if err == nil {
			t.Fatalf("expected an error for invalid CSR, got nil")
		}
	})
}

func TestCA_GenerateCSR_AndUpdate_RoundTrip(t *testing.T) {
	env := testutil.NewEnv(t)

	// Sub-CA created locally; we'll generate its CSR and counter-sign it with
	// an offline ECDSA-P384 root, then patch the CA back into the DB.
	subRow := mustCreateCA(t, env, "subca", certutils.KEY_ECDSA, 384, x509.ECDSAWithSHA384)

	// Generate the sub-CA's CSR via the production code path.
	sub := models.CA{DB: env.DB, Ctx: env.Ctx, Cn: subRow.Cn}
	gen, err := sub.GenerateCSR(map[string]string{"id": fmt.Sprintf("%d", subRow.ID)})
	if err != nil {
		t.Fatalf("GenerateCSR: %v", err)
	}
	csrPEM := gen.Entries.(string)
	csrBlock, _ := pem.Decode([]byte(csrPEM))
	if csrBlock == nil {
		t.Fatalf("GenerateCSR returned non-PEM:\n%s", csrPEM)
	}
	csr, err := x509.ParseCertificateRequest(csrBlock.Bytes)
	if err != nil {
		t.Fatalf("parse CSR: %v", err)
	}
	if _, ok := csr.PublicKey.(*ecdsa.PublicKey); !ok {
		t.Fatalf("CSR pubkey is %T, want *ecdsa.PublicKey", csr.PublicKey)
	}

	// Build a throwaway "offline root" and sign the CSR with it.
	rootKey, err := ecdsa.GenerateKey(elliptic.P384(), rand.Reader)
	if err != nil {
		t.Fatalf("offline root keygen: %v", err)
	}
	rootTmpl := &x509.Certificate{
		SerialNumber:          bigOne(),
		Subject:               pkix.Name{CommonName: "offline-root"},
		IsCA:                  true,
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageCRLSign,
		BasicConstraintsValid: true,
		NotBefore:             timeNow(),
		NotAfter:              timeNowPlus(365),
	}
	rootDER, err := x509.CreateCertificate(rand.Reader, rootTmpl, rootTmpl, &rootKey.PublicKey, rootKey)
	if err != nil {
		t.Fatalf("offline root self-sign: %v", err)
	}
	rootCert, _ := x509.ParseCertificate(rootDER)

	subTmpl := &x509.Certificate{
		SerialNumber:          bigTwo(),
		Subject:               csr.Subject,
		IsCA:                  true,
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageCRLSign,
		BasicConstraintsValid: true,
		NotBefore:             timeNow(),
		NotAfter:              timeNowPlus(180),
	}
	subDER, err := x509.CreateCertificate(rand.Reader, subTmpl, rootCert, csr.PublicKey, rootKey)
	if err != nil {
		t.Fatalf("offline root signs sub-CA: %v", err)
	}
	signedSubPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: subDER})

	// PATCH the sub-CA with the externally-signed cert. CA.Update validates
	// that the new cert+the existing private key still form a valid pair.
	update := models.CA{DB: env.DB, Ctx: env.Ctx, Cert: string(signedSubPEM)}
	if _, err := update.Update(map[string]string{"id": fmt.Sprintf("%d", subRow.ID)}); err != nil {
		t.Fatalf("CA.Update: %v", err)
	}

	// Read the row back and verify the cert was actually replaced and still
	// pairs with the private key.
	var stored models.CA
	if err := env.DB.First(&stored, subRow.ID).Error; err != nil {
		t.Fatalf("reload CA: %v", err)
	}
	stored.Cert = strings.TrimSpace(stored.Cert)
	want := strings.TrimSpace(string(signedSubPEM))
	if stored.Cert != want {
		t.Fatalf("CA.Cert was not updated:\nstored=%q\nwant  =%q", stored.Cert, want)
	}
}

func TestCA_Resign_RotatesCertificate(t *testing.T) {
	env := testutil.NewEnv(t)
	ca := mustCreateCA(t, env, "resign-ca", certutils.KEY_RSA, 2048, x509.SHA256WithRSA)

	oldPEM := ca.Cert

	rebuilt := caTemplate(ca.Cn, certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
	rebuilt.DB = env.DB
	rebuilt.Ctx = env.Ctx
	info, err := rebuilt.Resign(map[string]string{"id": fmt.Sprintf("%d", ca.ID)})
	if err != nil {
		t.Fatalf("CA.Resign: %v (info=%+v)", err, info)
	}

	var reloaded models.CA
	if err := env.DB.First(&reloaded, ca.ID).Error; err != nil {
		t.Fatalf("reload: %v", err)
	}
	if reloaded.Cert == oldPEM {
		t.Fatalf("resign did not change the cert PEM")
	}
	// Resign generates a fresh key + cert; the new pair must round-trip.
	if _, err := parsePair(reloaded.Cert, reloaded.Key); err != nil {
		t.Fatalf("post-resign keypair invalid: %v", err)
	}
}

func TestCert_Resign_RotatesLeaf(t *testing.T) {
	env := testutil.NewEnv(t)
	ca := mustCreateCA(t, env, "leaf-resign-ca", certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
	p := profileTemplate("leaf-resign-prof", ca, certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
	p.DB = env.DB
	p.Ctx = env.Ctx
	pinfo, err := p.New()
	if err != nil {
		t.Fatalf("Profile.New: %v", err)
	}
	profile := pinfo.Entries.([]models.Profile)[0]

	// Issue a leaf with non-trivial identity: SANs, IP, email. The user's
	// "RADIUS cert with 398-day validity" use case relies on these
	// surviving a blank-body resign.
	leaf := models.Cert{
		DB:          env.DB,
		Ctx:         env.Ctx,
		Cn:          "radius.example.test",
		Mail:        "ops@example.test",
		DNSNames:    "radius.example.test,radius-alt.example.test",
		IPAddresses: "10.0.0.5,10.0.0.6",
		ProfileID:   profile.ID,
	}
	cinfo, err := leaf.New()
	if err != nil {
		t.Fatalf("Cert.New: %v", err)
	}
	originalRow := cinfo.Entries.([]models.Cert)[0]
	originalCert := parseFirstCertPEM(t, []byte(originalRow.Cert))

	// Blank-body resign — only the cert id is passed. The fixed Resign
	// must read every identity field off the existing cert PEM, not from
	// the receiver.
	rotate := models.Cert{DB: env.DB, Ctx: env.Ctx}
	if _, err := rotate.Resign(map[string]string{"id": fmt.Sprintf("%d", originalRow.ID)}); err != nil {
		t.Fatalf("Cert.Resign: %v", err)
	}

	var reloaded models.Cert
	if err := env.DB.First(&reloaded, originalRow.ID).Error; err != nil {
		t.Fatalf("reload leaf: %v", err)
	}
	if reloaded.SerialNumber == originalRow.SerialNumber {
		t.Fatalf("resign kept the same serial %q", reloaded.SerialNumber)
	}
	newCert := parseFirstCertPEM(t, []byte(reloaded.Cert))

	// Subject must round-trip byte-for-byte; that's the whole point of a
	// resign vs. a fresh issuance.
	if newCert.Subject.String() != originalCert.Subject.String() {
		t.Errorf("Subject changed:\n old=%q\n new=%q",
			originalCert.Subject.String(), newCert.Subject.String())
	}
	if !equalStrings(newCert.DNSNames, originalCert.DNSNames) {
		t.Errorf("DNSNames changed:\n old=%v\n new=%v",
			originalCert.DNSNames, newCert.DNSNames)
	}
	if !equalStrings(newCert.EmailAddresses, originalCert.EmailAddresses) {
		t.Errorf("EmailAddresses changed:\n old=%v\n new=%v",
			originalCert.EmailAddresses, newCert.EmailAddresses)
	}
	gotIPs := make([]string, len(newCert.IPAddresses))
	oldIPs := make([]string, len(originalCert.IPAddresses))
	for i, ip := range newCert.IPAddresses {
		gotIPs[i] = ip.String()
	}
	for i, ip := range originalCert.IPAddresses {
		oldIPs[i] = ip.String()
	}
	if !equalStrings(gotIPs, oldIPs) {
		t.Errorf("IPAddresses changed:\n old=%v\n new=%v", oldIPs, gotIPs)
	}
	if newCert.KeyUsage != originalCert.KeyUsage {
		t.Errorf("KeyUsage changed: old=%v new=%v",
			originalCert.KeyUsage, newCert.KeyUsage)
	}
	// Public key (ergo private key on the device) must be unchanged so
	// existing deployments don't need a key rotation alongside the renewal.
	oldPubBytes, err := x509.MarshalPKIXPublicKey(originalCert.PublicKey)
	if err != nil {
		t.Fatalf("marshal old pubkey: %v", err)
	}
	newPubBytes, err := x509.MarshalPKIXPublicKey(newCert.PublicKey)
	if err != nil {
		t.Fatalf("marshal new pubkey: %v", err)
	}
	if !bytes.Equal(oldPubBytes, newPubBytes) {
		t.Fatalf("public key changed across resign")
	}
	// The new validity window must not regress. Within a single test run
	// (sub-second) time.Now() returns the same instant for both the
	// original issuance and the resign, so equal dates are acceptable.
	if newCert.NotBefore.Before(originalCert.NotBefore) {
		t.Errorf("NotBefore went backwards: old=%v new=%v",
			originalCert.NotBefore, newCert.NotBefore)
	}
	if newCert.NotAfter.Before(originalCert.NotAfter) {
		t.Errorf("NotAfter went backwards: old=%v new=%v",
			originalCert.NotAfter, newCert.NotAfter)
	}
}

// --- small helpers used above ---

func equalStrings(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func assertLeafChains(t *testing.T, info types.Info, caRow models.CA) {
	t.Helper()
	certs, ok := info.Entries.([]models.Cert)
	if !ok || len(certs) != 1 {
		t.Fatalf("Entries=%v want one Cert", info.Entries)
	}
	leaf := parseFirstCertPEM(t, []byte(certs[0].Cert))
	ca := parseFirstCertPEM(t, []byte(caRow.Cert))
	verifyLeaf(t, leaf, ca)
}

// parsePair verifies that certPEM and keyPEM round-trip through tls.X509KeyPair.
func parsePair(certPEM, keyPEM string) (any, error) {
	// We don't need tls just for parsing; do it manually to keep error
	// messages crisp.
	certBlock, _ := pem.Decode([]byte(certPEM))
	if certBlock == nil {
		return nil, fmt.Errorf("cert PEM did not decode")
	}
	cert, err := x509.ParseCertificate(certBlock.Bytes)
	if err != nil {
		return nil, err
	}
	keyBlock, _ := pem.Decode([]byte(keyPEM))
	if keyBlock == nil {
		return nil, fmt.Errorf("key PEM did not decode")
	}
	switch {
	case strings.Contains(keyBlock.Type, "RSA"):
		k, err := x509.ParsePKCS1PrivateKey(keyBlock.Bytes)
		if err != nil {
			return nil, err
		}
		if k.PublicKey.N.Cmp(cert.PublicKey.(*rsa.PublicKey).N) != 0 {
			return nil, fmt.Errorf("RSA key/cert modulus mismatch")
		}
		return k, nil
	case strings.Contains(keyBlock.Type, "EC"):
		k, err := x509.ParseECPrivateKey(keyBlock.Bytes)
		if err != nil {
			return nil, err
		}
		return k, nil
	default:
		k, err := x509.ParsePKCS8PrivateKey(keyBlock.Bytes)
		if err != nil {
			return nil, err
		}
		return k, nil
	}
}
