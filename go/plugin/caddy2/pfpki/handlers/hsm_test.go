package handlers_test

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"fmt"
	"net/http"
	"os"
	"strings"
	"testing"

	"github.com/eclipse-keypont/crypto11"
	"github.com/go-kit/log"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/hsm"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	scepclient "github.com/inverse-inc/scep/client"
	scep "github.com/inverse-inc/scep/scep"
	xocsp "golang.org/x/crypto/ocsp"
)

// testHSM returns the PKCS#11 token the HSM tests run against, e.g. a
// SoftHSM2 token:
//
//	PFPKI_TEST_PKCS11_MODULE=/usr/lib/softhsm/libsofthsm2.so
//	PFPKI_TEST_PKCS11_TOKEN=pfpki-test PFPKI_TEST_PKCS11_PIN=1234
func testHSM(t *testing.T) hsm.Config {
	t.Helper()
	cfg := hsm.Config{
		Module:     os.Getenv("PFPKI_TEST_PKCS11_MODULE"),
		TokenLabel: os.Getenv("PFPKI_TEST_PKCS11_TOKEN"),
		Pin:        os.Getenv("PFPKI_TEST_PKCS11_PIN"),
	}
	if cfg.Module == "" || cfg.TokenLabel == "" {
		t.Skip("PFPKI_TEST_PKCS11_MODULE / PFPKI_TEST_PKCS11_TOKEN not set")
	}
	return cfg
}

func doJSON(t *testing.T, env *testutil.Env, method, path, body string) (int, string) {
	t.Helper()
	req, err := http.NewRequest(method, env.Server.URL+path, bytes.NewBufferString(body))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	return resp.StatusCode, readBody(t, resp)
}

func mustCreateHSMCA(t *testing.T, env *testutil.Env, hsmID uint, cn string, kt types.Type, size int, digest x509.SignatureAlgorithm) models.CA {
	t.Helper()
	status, body := doJSON(t, env, "POST", "/api/v1/pki/cas/", fmt.Sprintf(`{
		"cn": "%s", "mail": "%s@example.test", "organisation": "Acme", "country": "US",
		"key_type": "%d", "key_size": "%d", "digest": "%d",
		"key_usage": "32|64", "extended_key_usage": "1|2", "days": "365",
		"hsm_id": "%d"
	}`, cn, cn, int(kt), size, int(digest), hsmID))
	if status/100 != 2 {
		t.Fatalf("POST /pki/cas (HSM) -> %d:\n%s", status, body)
	}
	var row models.CA
	if err := env.DB.Where("cn = ?", cn).First(&row).Error; err != nil {
		t.Fatalf("reload CA %q: %v", cn, err)
	}
	return row
}

func TestHSM_CA(t *testing.T) {
	cfg := testHSM(t)
	env := testutil.NewEnv(t)

	// --- HSM object: the PIN is checked against the token and never returned.
	status, body := doJSON(t, env, "POST", "/api/v1/pki/hsms/", fmt.Sprintf(`{"name":"bad","module":%q,"token_label":%q,"pin":"wrong-pin"}`, cfg.Module, cfg.TokenLabel))
	if status != http.StatusUnprocessableEntity {
		t.Fatalf("HSM with a wrong PIN -> %d, want 422:\n%s", status, body)
	}
	status, body = doJSON(t, env, "POST", "/api/v1/pki/hsms/", fmt.Sprintf(`{"name":"test-hsm","module":%q,"token_label":%q,"pin":%q}`, cfg.Module, cfg.TokenLabel, cfg.Pin))
	if status/100 != 2 || strings.Contains(body, `"pin"`) {
		t.Fatalf("POST /pki/hsms -> %d:\n%s", status, body)
	}
	var h models.HSM
	if err := env.DB.Where("name = ?", "test-hsm").First(&h).Error; err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{"/api/v1/pki/hsms/", fmt.Sprintf("/api/v1/pki/hsm/%d", h.ID)} {
		status, body = doJSON(t, env, "GET", path, "")
		if status != http.StatusOK || strings.Contains(body, `"pin"`) {
			t.Fatalf("GET %s -> %d, the PIN must not be returned:\n%s", path, status, body)
		}
	}

	// --- RSA CA held in the HSM.
	caRow := mustCreateHSMCA(t, env, h.ID, "hsm-rsa-ca", certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
	if caRow.Key != "" || caRow.HsmID != h.ID || len(caRow.HsmKeyID) != 32 {
		t.Fatalf("HSM CA row: key=%d bytes hsm_id=%d hsm_key_id=%q", len(caRow.Key), caRow.HsmID, caRow.HsmKeyID)
	}
	caCert := parsePEMCert(t, caRow.Cert)
	if err := caCert.CheckSignatureFrom(caCert); err != nil {
		t.Fatalf("CA self-signature: %v", err)
	}
	roots := x509.NewCertPool()
	roots.AddCert(caCert)

	// Admin issuance, OCSP, revocation.
	prof := mustCreateProfileFromHTTP(t, env, "hsm-prof", caRow, certutils.KEY_RSA, 2048, x509.SHA256WithRSA)
	_, leafID := mustIssueLeafFromHTTP(t, env, prof, "hsm-leaf")
	leaf := loadLeafFromDB(t, env, leafID)
	if _, err := leaf.Verify(x509.VerifyOptions{Roots: roots, KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageAny}}); err != nil {
		t.Fatalf("leaf issued by the HSM CA: %v", err)
	}
	if resp := postOCSP(t, env, leaf, caCert); resp.Status != xocsp.Good {
		t.Fatalf("OCSP status %d, want Good", resp.Status)
	}
	if err := revokeLeaf(t, env, leafID, xocsp.KeyCompromise); err != nil {
		t.Fatal(err)
	}
	if resp := postOCSP(t, env, leaf, caCert); resp.Status != xocsp.Revoked {
		t.Fatalf("OCSP status %d after revocation, want Revoked", resp.Status)
	}

	// SCEP: the HSM key decrypts the request and signs the response, and the
	// client decrypts the issued certificate.
	if err := env.DB.Model(&models.Profile{}).Where("id = ?", prof.ID).Updates(map[string]any{
		"scep_enabled": 1, "scep_challenge_password": "hsm123",
	}).Error; err != nil {
		t.Fatal(err)
	}
	env.DB.Model(&models.CA{}).Where("id = ?", caRow.ID).Update("serial_number", 100)
	scepLeaf := scepEnroll(t, env, "hsm-prof", "hsm-scep-client", "hsm123")
	if _, err := scepLeaf.Verify(x509.VerifyOptions{Roots: roots, KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageAny}}); err != nil {
		t.Fatalf("SCEP leaf issued by the HSM CA: %v", err)
	}

	// A CSR for the CA itself, and a re-signed CA certificate keep the HSM key.
	status, body = doJSON(t, env, "POST", fmt.Sprintf("/api/v1/pki/ca/csr/%d", caRow.ID), `{"cn":"hsm-rsa-ca","organisation":"Acme"}`)
	if status/100 != 2 || !strings.Contains(body, "CERTIFICATE REQUEST") {
		t.Fatalf("CSR of the HSM CA -> %d:\n%s", status, body)
	}
	status, body = doJSON(t, env, "POST", fmt.Sprintf("/api/v1/pki/ca/resign/%d", caRow.ID), `{
		"cn":"hsm-rsa-ca","mail":"hsm-rsa-ca@example.test","organisation":"Acme","country":"US",
		"key_type":"1","key_size":"2048","digest":"4","key_usage":"32|64","extended_key_usage":"1|2","days":"730"}`)
	if status/100 != 2 {
		t.Fatalf("resign HSM CA -> %d:\n%s", status, body)
	}
	var resigned models.CA
	env.DB.First(&resigned, caRow.ID)
	resignedCert := parsePEMCert(t, resigned.Cert)
	if resigned.Key != "" || !resignedCert.PublicKey.(*rsa.PublicKey).Equal(caCert.PublicKey) || resigned.Cert == caRow.Cert {
		t.Fatalf("resigned HSM CA: key=%d bytes, same public key=%v, new cert=%v", len(resigned.Key),
			resignedCert.PublicKey.(*rsa.PublicKey).Equal(caCert.PublicKey), resigned.Cert != caRow.Cert)
	}

	// --- While the token is logged in (a CA key is in use), a wrong PIN
	// is still refused, and the CAs keep working afterwards.
	status, body = doJSON(t, env, "POST", "/api/v1/pki/hsms/", fmt.Sprintf(`{"name":"bad-while-open","module":%q,"token_label":%q,"pin":"wrong-pin"}`, cfg.Module, cfg.TokenLabel))
	if status != http.StatusUnprocessableEntity {
		t.Fatalf("HSM with a wrong PIN while the token is open -> %d, want 422:\n%s", status, body)
	}
	_, reopenedID := mustIssueLeafFromHTTP(t, env, prof, "hsm-leaf-reopened")
	if _, err := loadLeafFromDB(t, env, reopenedID).Verify(x509.VerifyOptions{Roots: roots, KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageAny}}); err != nil {
		t.Fatalf("leaf issued after a refused PIN: %v", err)
	}

	// --- A CA that can't be created doesn't leave its key in the token.
	keysBefore := countTokenKeys(t, cfg)
	if status, body = doJSON(t, env, "POST", "/api/v1/pki/cas/", fmt.Sprintf(`{
		"cn": "hsm-rsa-ca", "key_type": "%d", "key_size": "2048", "digest": "%d",
		"key_usage": "32|64", "extended_key_usage": "1|2", "days": "365", "hsm_id": "%d"}`,
		int(certutils.KEY_RSA), int(x509.SHA256WithRSA), h.ID)); status/100 == 2 {
		t.Fatalf("duplicate CA accepted:\n%s", body)
	}
	if keysAfter := countTokenKeys(t, cfg); keysAfter != keysBefore {
		t.Fatalf("%d key pairs in the token after a failed CA creation, want %d", keysAfter, keysBefore)
	}

	// --- ECDSA CA held in the HSM.
	ecCA := mustCreateHSMCA(t, env, h.ID, "hsm-ec-ca", certutils.KEY_ECDSA, 256, x509.ECDSAWithSHA256)
	ecProf := mustCreateProfileFromHTTP(t, env, "hsm-ec-prof", ecCA, certutils.KEY_ECDSA, 256, x509.ECDSAWithSHA256)
	_, ecLeafID := mustIssueLeafFromHTTP(t, env, ecProf, "hsm-ec-leaf")
	ecRoots := x509.NewCertPool()
	ecRoots.AddCert(parsePEMCert(t, ecCA.Cert))
	if _, err := loadLeafFromDB(t, env, ecLeafID).Verify(x509.VerifyOptions{Roots: ecRoots, KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageAny}}); err != nil {
		t.Fatalf("leaf issued by the ECDSA HSM CA: %v", err)
	}

	// --- Key types an HSM can't hold are refused.
	status, body = doJSON(t, env, "POST", "/api/v1/pki/cas/", fmt.Sprintf(`{
		"cn": "hsm-ed-ca", "key_type": "%d", "key_size": "256", "digest": "%d",
		"key_usage": "32|64", "extended_key_usage": "1|2", "days": "365", "hsm_id": "%d"}`,
		int(certutils.KEY_ED25519), int(x509.PureEd25519), h.ID))
	if status/100 == 2 {
		t.Fatalf("Ed25519 CA in an HSM accepted:\n%s", body)
	}

	// --- An HSM holding CA keys can't be deleted; its PIN can be changed
	// only to one that opens the token, and is kept when omitted.
	if status, body = doJSON(t, env, "DELETE", fmt.Sprintf("/api/v1/pki/hsm/%d", h.ID), ""); status != http.StatusConflict {
		t.Fatalf("DELETE an HSM in use -> %d, want 409:\n%s", status, body)
	}
	if status, body = doJSON(t, env, "PATCH", fmt.Sprintf("/api/v1/pki/hsm/%d", h.ID), fmt.Sprintf(`{"module":%q,"token_label":%q,"pin":"wrong-pin"}`, cfg.Module, cfg.TokenLabel)); status != http.StatusUnprocessableEntity {
		t.Fatalf("PATCH with a wrong PIN -> %d, want 422:\n%s", status, body)
	}
	if status, body = doJSON(t, env, "PATCH", fmt.Sprintf("/api/v1/pki/hsm/%d", h.ID), fmt.Sprintf(`{"module":%q,"token_label":%q}`, cfg.Module, cfg.TokenLabel)); status != http.StatusOK {
		t.Fatalf("PATCH without a PIN -> %d:\n%s", status, body)
	}
	_, leaf2ID := mustIssueLeafFromHTTP(t, env, prof, "hsm-leaf-after-patch")
	if _, err := loadLeafFromDB(t, env, leaf2ID).Verify(x509.VerifyOptions{Roots: roots, KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageAny}}); err != nil {
		t.Fatalf("leaf issued after the HSM update: %v", err)
	}
	var reloaded models.HSM
	env.DB.First(&reloaded, h.ID)
	if reloaded.Pin != cfg.Pin {
		t.Fatalf("the PIN was not kept by an update without one")
	}
}

// countTokenKeys counts the key pairs in the token, through a context of
// its own.
func countTokenKeys(t *testing.T, cfg hsm.Config) int {
	t.Helper()
	ctx, err := crypto11.Configure(&crypto11.Config{Path: cfg.Module, TokenLabel: cfg.TokenLabel, Pin: cfg.Pin})
	if err != nil {
		t.Fatalf("open the token: %v", err)
	}
	defer ctx.Close()
	keys, err := ctx.FindAllKeyPairs()
	if err != nil {
		t.Fatalf("list the key pairs: %v", err)
	}
	return len(keys)
}

// scepEnroll runs a full SCEP enrollment and returns the certificate the
// client decrypts from the CertRep.
func scepEnroll(t *testing.T, env *testutil.Env, profile, cn, challenge string) *x509.Certificate {
	t.Helper()
	clientKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	csr, err := buildCSRWithChallenge(clientKey, cn, challenge)
	if err != nil {
		t.Fatal(err)
	}
	signerCert, err := selfSignClient(clientKey, csr)
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	logger := log.NewNopLogger()
	client, err := scepclient.New(env.Server.URL+"/api/v1/pki/scep/"+profile, logger)
	if err != nil {
		t.Fatal(err)
	}
	caResp, _, err := client.GetCACert(ctx, "")
	if err != nil {
		t.Fatalf("GetCACert: %v", err)
	}
	msg, err := scep.NewCSRRequest(csr, &scep.PKIMessage{
		MessageType:   scep.PKCSReq,
		Recipients:    parseCAChainResponse(t, caResp),
		SignerKey:     clientKey,
		SignerCert:    signerCert,
		CSRReqMessage: &scep.CSRReqMessage{ChallengePassword: challenge},
	}, scep.WithLogger(logger))
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
	if err := respMsg.DecryptPKIEnvelope(signerCert, clientKey); err != nil {
		t.Fatalf("decrypt the CertRep: %v", err)
	}
	return respMsg.CertRepMessage.Certificate
}

