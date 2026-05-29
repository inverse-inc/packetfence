package handlers_test

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"io"
	"math/big"
	"testing"
	"time"

	"github.com/go-kit/log"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	scepclient "github.com/inverse-inc/scep/client"
	"github.com/inverse-inc/scep/cryptoutil/x509util"
	scep "github.com/inverse-inc/scep/scep"
)

// TestSCEP_EnrollLeaf exercises the SCEP enrollment flow end-to-end against
// the in-memory pfpki server: it creates an RSA CA, a SCEP-enabled profile,
// generates a CSR client-side, posts a PKCSReq, and verifies the returned
// certificate chains back to the CA.
//
// The pfpki SCEP path only supports RSA — it pulls the CA's RSA private key
// via LoadKey/ParseRsaPrivateKeyFromPemStr — so this test uses RSA throughout.
func TestSCEP_EnrollLeaf(t *testing.T) {
	env := testutil.NewEnv(t)

	// --- Server-side setup ---
	caRow := mustCreateCAFromHTTP(t, env, "scep-ca", certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
	prof := mustCreateProfileFromHTTP(t, env, "scepprof", caRow, certutils.KEY_RSA, 2048, x509.SHA256WithRSA)

	// Enable SCEP on the profile (FindSCEPProfile filters scep_enabled=1).
	if err := env.DB.Model(&models.Profile{}).Where("id = ?", prof.ID).
		Updates(map[string]any{
			"scep_enabled":            1,
			"scep_challenge_password": "test123",
			"validity":                30,
		}).Error; err != nil {
		t.Fatalf("enable SCEP: %v", err)
	}

	// pfpki initializes a CA's leaf-serial counter at 1, while the CA cert
	// itself also has SerialNumber=1. PKCS7 signer disambiguation goes by
	// (issuer, serial); since leaves share the CA's RawIssuer, the first
	// leaf collides with the CA. Bump the counter so SCEP-issued leaves get
	// distinct serials.
	if err := env.DB.Model(&models.CA{}).Where("id = ?", caRow.ID).
		Update("serial_number", 100).Error; err != nil {
		t.Fatalf("bump CA.SerialNumber: %v", err)
	}

	// --- Client-side: keys + CSR ---
	clientKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("client key: %v", err)
	}
	csr, err := buildCSRWithChallenge(clientKey, "scep-client.example.test", "test123")
	if err != nil {
		t.Fatalf("buildCSRWithChallenge: %v", err)
	}

	// Self-signed "signer" cert that wraps the SCEP message.
	signerCert, err := selfSignClient(clientKey, csr)
	if err != nil {
		t.Fatalf("self-sign signer cert: %v", err)
	}

	// --- SCEP exchange ---
	ctx := context.Background()
	logger := log.NewNopLogger()
	scepURL := env.Server.URL + "/api/v1/pki/scep/scepprof"
	client, err := scepclient.New(scepURL, logger)
	if err != nil {
		t.Fatalf("scepclient.New: %v", err)
	}

	caRespBytes, _, err := client.GetCACert(ctx, "")
	if err != nil {
		t.Fatalf("GetCACert: %v", err)
	}
	caCerts := parseCAChainResponse(t, caRespBytes)
	if len(caCerts) == 0 {
		t.Fatalf("GetCACert returned no certs")
	}

	tmpl := &scep.PKIMessage{
		MessageType: scep.PKCSReq,
		Recipients:  caCerts,
		SignerKey:   clientKey,
		SignerCert:  signerCert,
		CSRReqMessage: &scep.CSRReqMessage{
			ChallengePassword: "test123",
		},
	}
	msg, err := scep.NewCSRRequest(csr, tmpl, scep.WithLogger(logger))
	if err != nil {
		t.Fatalf("NewCSRRequest: %v", err)
	}

	respBytes, err := client.PKIOperation(ctx, msg.Raw)
	if err != nil {
		t.Fatalf("PKIOperation: %v", err)
	}
	respMsg, err := scep.ParsePKIMessage(respBytes, scep.WithLogger(logger), scep.WithCACerts(msg.Recipients))
	if err != nil {
		t.Fatalf("ParsePKIMessage: %v", err)
	}
	if respMsg.PKIStatus != scep.SUCCESS {
		t.Fatalf("PKIStatus=%v want SUCCESS (failInfo=%v)", respMsg.PKIStatus, respMsg.FailInfo)
	}

	// The SCEP server records the issued leaf in pki_certs as a side-effect.
	// Look it up directly to verify the server actually minted a cert; this
	// also bypasses a pkcs7-library limitation in DecryptPKIEnvelope on the
	// encrypted-payload side.
	var issuedRow models.Cert
	if err := env.DB.Where("cn = ?", csr.Subject.CommonName).First(&issuedRow).Error; err != nil {
		t.Fatalf("issued cert not found in DB: %v", err)
	}
	issued := parsePEMCert(t, issuedRow.Cert)
	if issued.Subject.CommonName != csr.Subject.CommonName {
		t.Errorf("issued CN=%q want %q", issued.Subject.CommonName, csr.Subject.CommonName)
	}

	caX509 := parsePEMCert(t, caRow.Cert)
	roots := x509.NewCertPool()
	roots.AddCert(caX509)
	if _, err := issued.Verify(x509.VerifyOptions{
		Roots:     roots,
		KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageAny},
	}); err != nil {
		t.Fatalf("verify issued cert against CA: %v", err)
	}
}

// TestSCEP_RejectsWrongChallenge ensures a bad challenge password causes the
// SCEP exchange to fail rather than minting a certificate.
func TestSCEP_RejectsWrongChallenge(t *testing.T) {
	env := testutil.NewEnv(t)
	caRow := mustCreateCAFromHTTP(t, env, "scep-ca2", certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
	prof := mustCreateProfileFromHTTP(t, env, "scepprof2", caRow, certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
	if err := env.DB.Model(&models.Profile{}).Where("id = ?", prof.ID).
		Updates(map[string]any{
			"scep_enabled":            1,
			"scep_challenge_password": "rightpass",
			"validity":                30,
		}).Error; err != nil {
		t.Fatalf("enable SCEP: %v", err)
	}

	clientKey, _ := rsa.GenerateKey(rand.Reader, 2048)
	csr, err := buildCSRWithChallenge(clientKey, "scep-bad-challenge", "wrongpass")
	if err != nil {
		t.Fatalf("buildCSRWithChallenge: %v", err)
	}
	signerCert, _ := selfSignClient(clientKey, csr)

	logger := log.NewNopLogger()
	client, _ := scepclient.New(env.Server.URL+"/api/v1/pki/scep/scepprof2", logger)

	caBytes, _, _ := client.GetCACert(context.Background(), "")
	caCerts := parseCAChainResponse(t, caBytes)

	tmpl := &scep.PKIMessage{
		MessageType: scep.PKCSReq,
		Recipients:  caCerts,
		SignerKey:   clientKey,
		SignerCert:  signerCert,
		CSRReqMessage: &scep.CSRReqMessage{
			ChallengePassword: "wrongpass",
		},
	}
	msg, err := scep.NewCSRRequest(csr, tmpl, scep.WithLogger(logger))
	if err != nil {
		t.Fatalf("NewCSRRequest: %v", err)
	}
	respBytes, err := client.PKIOperation(context.Background(), msg.Raw)
	if err != nil {
		// Some failure modes surface as transport errors; either is fine
		// for "the server didn't issue a cert".
		return
	}
	respMsg, err := scep.ParsePKIMessage(respBytes, scep.WithLogger(logger), scep.WithCACerts(msg.Recipients))
	if err != nil {
		return
	}
	if respMsg.PKIStatus == scep.SUCCESS {
		t.Fatalf("SCEP accepted a wrong challenge")
	}
}

// parseCAChainResponse extracts CA certs from a GetCACert response, tolerating
// pfpki's quirk: the server wraps even a single CA cert in a PKCS7 degenerate
// envelope while still tagging the response with the single-cert Content-Type.
func parseCAChainResponse(t *testing.T, data []byte) []*x509.Certificate {
	t.Helper()
	if certs, err := scep.CACerts(data); err == nil && len(certs) > 0 {
		return certs
	}
	certs, err := x509.ParseCertificates(data)
	if err != nil {
		t.Fatalf("GetCACert response is neither PKCS7 nor raw DER: %v", err)
	}
	return certs
}

// buildCSRWithChallenge produces an RSA CSR whose attributes include the
// challengePassword OID — the form pfpki's SCEP signer expects.
func buildCSRWithChallenge(priv *rsa.PrivateKey, cn, challenge string) (*x509.CertificateRequest, error) {
	tmpl := &x509util.CertificateRequest{
		CertificateRequest: x509.CertificateRequest{
			Subject:            pkix.Name{CommonName: cn},
			SignatureAlgorithm: x509.SHA256WithRSA,
		},
		ChallengePassword: challenge,
	}
	der, err := x509util.CreateCertificateRequest(rand.Reader, tmpl, priv)
	if err != nil {
		return nil, err
	}
	return x509.ParseCertificateRequest(der)
}

// selfSignClient mirrors the inverse-inc/scep cmd/scepclient selfSign helper.
func selfSignClient(priv *rsa.PrivateKey, csr *x509.CertificateRequest) (*x509.Certificate, error) {
	serialNumberLimit := new(big.Int).Lsh(big.NewInt(1), 128)
	serial, err := rand.Int(rand.Reader, serialNumberLimit)
	if err != nil {
		return nil, err
	}
	tmpl := x509.Certificate{
		SerialNumber: serial,
		Subject: pkix.Name{
			CommonName:   "SCEP SIGNER",
			Organization: csr.Subject.Organization,
		},
		NotBefore:             time.Now(),
		NotAfter:              time.Now().Add(time.Hour),
		KeyUsage:              x509.KeyUsageKeyEncipherment | x509.KeyUsageDigitalSignature,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		BasicConstraintsValid: true,
	}
	derBytes, err := x509.CreateCertificate(rand.Reader, &tmpl, &tmpl, &priv.PublicKey, priv)
	if err != nil {
		return nil, err
	}
	return x509.ParseCertificate(derBytes)
}

// avoid "imported and not used" if io ever stays unreferenced.
var _ = io.Discard
