package acme_test

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"io"
	"math/big"
	"net/http"
	"testing"
	"time"

	"github.com/fxamacker/cbor/v2"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
)

// appleOIDs is the subset of 1.2.840.113635.100.8.* the validator
// looks for. Mirrors device_attest01.go's set — duplicated in the test
// so a renamed OID over there breaks the test cleanly rather than
// silently.
var (
	oidAppleNonce  = asn1.ObjectIdentifier{1, 2, 840, 113635, 100, 8, 2}
	oidAppleUDID   = asn1.ObjectIdentifier{1, 2, 840, 113635, 100, 8, 3}
	oidAppleSerial = asn1.ObjectIdentifier{1, 2, 840, 113635, 100, 8, 5}
)

// appleFixture is a synthetic Apple attestation chain (root + leaf)
// with operator-supplied UDID / Serial / nonce on the leaf. The
// produced rootPEM goes into Profile.AcmeAttestationRoots so the
// validator's resolveAttestationRoots accepts it.
type appleFixture struct {
	rootCert    *x509.Certificate
	rootPEM     []byte
	leafCert    *x509.Certificate
	leafDER     []byte
	chainCBOR   []byte // the CBOR-encoded attestation object the device would post
	udid        string
	serial      string
}

// buildAppleFixture mints a minimal root and an attestation leaf
// signed by it, then CBOR-encodes a {fmt:"apple",attStmt:{x5c:[leaf]}}
// object. The leaf carries OIDs 8.{2,3,5} with the values supplied
// (nonce is wrapped in a bare OCTET STRING — the validator accepts
// every shape Apple has shipped).
func buildAppleFixture(t *testing.T, nonce []byte, udid, serial string) *appleFixture {
	t.Helper()
	rootKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("root key: %v", err)
	}
	rootTmpl := &x509.Certificate{
		SerialNumber:          big.NewInt(1),
		Subject:               pkix.Name{CommonName: "Apple Test Attestation Root"},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().Add(24 * time.Hour),
		IsCA:                  true,
		BasicConstraintsValid: true,
		KeyUsage:              x509.KeyUsageCertSign,
	}
	rootDER, err := x509.CreateCertificate(rand.Reader, rootTmpl, rootTmpl, &rootKey.PublicKey, rootKey)
	if err != nil {
		t.Fatalf("sign root: %v", err)
	}
	rootCert, _ := x509.ParseCertificate(rootDER)

	leafKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("leaf key: %v", err)
	}

	// Wrap the nonce as a bare OCTET STRING — the validator accepts
	// SEQUENCE{OCTETSTRING}, bare OCTET STRING, and raw 32-byte forms.
	// Bare is the simplest to produce in tests.
	nonceExt, err := asn1.Marshal(nonce)
	if err != nil {
		t.Fatalf("marshal nonce ext: %v", err)
	}
	udidExt, err := asn1.MarshalWithParams(udid, "utf8")
	if err != nil {
		t.Fatalf("marshal udid: %v", err)
	}
	serialExt, err := asn1.MarshalWithParams(serial, "utf8")
	if err != nil {
		t.Fatalf("marshal serial: %v", err)
	}

	leafTmpl := &x509.Certificate{
		SerialNumber: big.NewInt(2),
		Subject:      pkix.Name{CommonName: "Apple Test Attestation Leaf"},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(24 * time.Hour),
		ExtraExtensions: []pkix.Extension{
			{Id: oidAppleNonce, Value: nonceExt},
			{Id: oidAppleUDID, Value: udidExt},
			{Id: oidAppleSerial, Value: serialExt},
		},
	}
	leafDER, err := x509.CreateCertificate(rand.Reader, leafTmpl, rootCert, &leafKey.PublicKey, rootKey)
	if err != nil {
		t.Fatalf("sign leaf: %v", err)
	}
	leafCert, _ := x509.ParseCertificate(leafDER)

	rootPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: rootDER})

	att := map[string]any{
		"fmt": "apple",
		"attStmt": map[string]any{
			"x5c": [][]byte{leafDER},
		},
		"authData": []byte{}, // Apple format doesn't use it; keep the field present so non-strict decoders are happy
	}
	cborBytes, err := cbor.Marshal(att)
	if err != nil {
		t.Fatalf("cbor marshal: %v", err)
	}

	return &appleFixture{
		rootCert:  rootCert,
		rootPEM:   rootPEM,
		leafCert:  leafCert,
		leafDER:   leafDER,
		chainCBOR: cborBytes,
		udid:      udid,
		serial:    serial,
	}
}

func TestDeviceAttest01_Happy(t *testing.T) {
	env := testutil.NewEnv(t)
	profName := mustEnableAcmeProfile(t, env, "acme-attest-ok")

	// Boot an account first so we can compute the JWK thumbprint and
	// build the nonce binding. bootstrapAcmeAccount has the side
	// effect of setting AcmeEabRequired=0, which we want anyway.
	client, _ := bootstrapAcmeAccount(t, env, profName)
	thumb := mustThumbprint(t, client.jwk)

	// We don't know the challenge token until new-order runs, but the
	// nonce binding is SHA256(token || "." || thumbprint). Trick: run
	// the order first to capture the token, then build the fixture.
	// runDeviceAttestFlow does both halves; here we inline so we can
	// thread the token through to the fixture.

	// Step 1: configure profile + create order, returning the token
	// the validator will compute the expected nonce against.
	udid := "00008101-001AABCDEF01"
	if err := env.DB.Model(&models.Profile{}).Where("name = ?", profName).
		Updates(map[string]any{
			"acme_allowed_identifiers": "permanent-identifier",
			"acme_attestation_formats": "apple",
		}).Error; err != nil {
		t.Fatalf("configure profile: %v", err)
	}
	// Re-fetch kid in case bootstrap ran before the profile flips.
	createURL := newOrderURL(env, profName)
	// kid we already have via the account creation we did inside
	// bootstrapAcmeAccount — read it out of the DB.
	var acct models.AcmeAccount
	if err := env.DB.Where("key_thumbprint = ?", thumb).First(&acct).Error; err != nil {
		t.Fatalf("locate account: %v", err)
	}
	kid := acct.KeyID

	jws := client.signed(createURL, modeKID, kid, client.fetchNonce(), map[string]any{
		"identifiers": []map[string]string{
			{"type": "permanent-identifier", "value": udid},
		},
	})
	cr := client.post(t, createURL, jws)
	defer cr.Body.Close()
	if cr.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(cr.Body)
		t.Fatalf("new-order: status=%d body=%s", cr.StatusCode, string(body))
	}
	var orderBody struct {
		Authorizations []string `json:"authorizations"`
	}
	_ = json.NewDecoder(cr.Body).Decode(&orderBody)

	// Step 2: read authz to get the challenge token.
	authzJWS := client.signed(orderBody.Authorizations[0], modeKID, kid, client.fetchNonce(), "")
	authzResp := client.post(t, orderBody.Authorizations[0], authzJWS)
	defer authzResp.Body.Close()
	var authzBody struct {
		Challenges []struct {
			Type, URL, Token string
		}
	}
	_ = json.NewDecoder(authzResp.Body).Decode(&authzBody)
	if len(authzBody.Challenges) != 1 || authzBody.Challenges[0].Type != "device-attest-01" {
		t.Fatalf("challenges=%+v", authzBody.Challenges)
	}
	chall := authzBody.Challenges[0]

	// Step 3: build the fixture with the correct nonce SHA256(token.thumb)
	// and install its root on the profile.
	digest := sha256.Sum256([]byte(chall.Token + "." + thumb))
	fix := buildAppleFixture(t, digest[:], udid, "")
	if err := env.DB.Model(&models.Profile{}).Where("name = ?", profName).
		Update("acme_attestation_roots", string(fix.rootPEM)).Error; err != nil {
		t.Fatalf("install attestation root: %v", err)
	}

	// Step 4: POST the challenge with the wrapped attestation.
	payload := map[string]any{
		"attObj": base64.RawURLEncoding.EncodeToString(fix.chainCBOR),
	}
	chJWS := client.signed(chall.URL, modeKID, kid, client.fetchNonce(), payload)
	chResp := client.post(t, chall.URL, chJWS)
	defer chResp.Body.Close()
	if chResp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(chResp.Body)
		t.Fatalf("challenge: status=%d body=%s", chResp.StatusCode, string(body))
	}

	// Verify the challenge + authz + order all advanced.
	var ch models.AcmeChallenge
	if err := env.DB.Where("token = ?", chall.Token).First(&ch).Error; err != nil {
		t.Fatalf("locate challenge: %v", err)
	}
	if ch.Status != "valid" {
		t.Errorf("challenge.status=%q want valid", ch.Status)
	}
	var authz models.AcmeAuthz
	if err := env.DB.First(&authz, ch.AuthzID).Error; err != nil {
		t.Fatalf("locate authz: %v", err)
	}
	if authz.Status != "valid" {
		t.Errorf("authz.status=%q want valid", authz.Status)
	}
	var order models.AcmeOrder
	if err := env.DB.First(&order, authz.OrderID).Error; err != nil {
		t.Fatalf("locate order: %v", err)
	}
	if order.Status != "ready" {
		t.Errorf("order.status=%q want ready", order.Status)
	}
}

// TestDeviceAttest01_BadNonce confirms a chain whose embedded nonce
// doesn't match SHA256(token.thumbprint) fails closed — the most
// security-relevant negative case.
func TestDeviceAttest01_BadNonce(t *testing.T) {
	env := testutil.NewEnv(t)
	profName := mustEnableAcmeProfile(t, env, "acme-attest-badnonce")
	udid := "00008101-deadbeef"

	client, _ := bootstrapAcmeAccount(t, env, profName)
	thumb := mustThumbprint(t, client.jwk)
	_ = env.DB.Model(&models.Profile{}).Where("name = ?", profName).
		Updates(map[string]any{
			"acme_allowed_identifiers": "permanent-identifier",
			"acme_attestation_formats": "apple",
		})
	var acct models.AcmeAccount
	_ = env.DB.Where("key_thumbprint = ?", thumb).First(&acct).Error
	kid := acct.KeyID

	createURL := newOrderURL(env, profName)
	jws := client.signed(createURL, modeKID, kid, client.fetchNonce(), map[string]any{
		"identifiers": []map[string]string{{"type": "permanent-identifier", "value": udid}},
	})
	cr := client.post(t, createURL, jws)
	defer cr.Body.Close()
	var ob struct{ Authorizations []string }
	_ = json.NewDecoder(cr.Body).Decode(&ob)

	azJWS := client.signed(ob.Authorizations[0], modeKID, kid, client.fetchNonce(), "")
	azResp := client.post(t, ob.Authorizations[0], azJWS)
	defer azResp.Body.Close()
	var ab struct {
		Challenges []struct{ URL, Token string }
	}
	_ = json.NewDecoder(azResp.Body).Decode(&ab)
	chall := ab.Challenges[0]

	// Wrong nonce: deliberately scramble.
	bad := sha256.Sum256([]byte("WRONG"))
	fix := buildAppleFixture(t, bad[:], udid, "")
	_ = env.DB.Model(&models.Profile{}).Where("name = ?", profName).
		Update("acme_attestation_roots", string(fix.rootPEM))

	chJWS := client.signed(chall.URL, modeKID, kid, client.fetchNonce(), map[string]any{
		"attObj": base64.RawURLEncoding.EncodeToString(fix.chainCBOR),
	})
	chResp := client.post(t, chall.URL, chJWS)
	defer chResp.Body.Close()
	// The /chall POST returns 200 with the current state; the
	// challenge itself moves to invalid because the validator
	// rejected the nonce.
	var ch models.AcmeChallenge
	_ = env.DB.Where("token = ?", chall.Token).First(&ch).Error
	if ch.Status != "invalid" {
		t.Errorf("challenge.status=%q want invalid", ch.Status)
	}
	if ch.Error == "" {
		t.Errorf("challenge.error is empty; validator should record a problem doc")
	}
}

// TestDeviceAttest01_IdentifierMismatch: the chain's UDID/serial
// doesn't match the order's permanent-identifier.
func TestDeviceAttest01_IdentifierMismatch(t *testing.T) {
	env := testutil.NewEnv(t)
	profName := mustEnableAcmeProfile(t, env, "acme-attest-mismatch")

	client, _ := bootstrapAcmeAccount(t, env, profName)
	thumb := mustThumbprint(t, client.jwk)
	_ = env.DB.Model(&models.Profile{}).Where("name = ?", profName).
		Updates(map[string]any{
			"acme_allowed_identifiers": "permanent-identifier",
			"acme_attestation_formats": "apple",
		})
	var acct models.AcmeAccount
	_ = env.DB.Where("key_thumbprint = ?", thumb).First(&acct).Error
	kid := acct.KeyID

	createURL := newOrderURL(env, profName)
	jws := client.signed(createURL, modeKID, kid, client.fetchNonce(), map[string]any{
		"identifiers": []map[string]string{{"type": "permanent-identifier", "value": "expected-udid"}},
	})
	cr := client.post(t, createURL, jws)
	defer cr.Body.Close()
	var ob struct{ Authorizations []string }
	_ = json.NewDecoder(cr.Body).Decode(&ob)

	azJWS := client.signed(ob.Authorizations[0], modeKID, kid, client.fetchNonce(), "")
	azResp := client.post(t, ob.Authorizations[0], azJWS)
	defer azResp.Body.Close()
	var ab struct {
		Challenges []struct{ URL, Token string }
	}
	_ = json.NewDecoder(azResp.Body).Decode(&ab)
	chall := ab.Challenges[0]

	// Correct nonce but wrong UDID on the leaf.
	digest := sha256.Sum256([]byte(chall.Token + "." + thumb))
	fix := buildAppleFixture(t, digest[:], "different-udid", "different-serial")
	_ = env.DB.Model(&models.Profile{}).Where("name = ?", profName).
		Update("acme_attestation_roots", string(fix.rootPEM))

	chJWS := client.signed(chall.URL, modeKID, kid, client.fetchNonce(), map[string]any{
		"attObj": base64.RawURLEncoding.EncodeToString(fix.chainCBOR),
	})
	chResp := client.post(t, chall.URL, chJWS)
	defer chResp.Body.Close()

	var ch models.AcmeChallenge
	_ = env.DB.Where("token = ?", chall.Token).First(&ch).Error
	if ch.Status != "invalid" {
		t.Errorf("challenge.status=%q want invalid", ch.Status)
	}
}

// TestDeviceAttest01_UntrustedRoot: the chain validates cryptographically
// but its root isn't installed on the profile.
func TestDeviceAttest01_UntrustedRoot(t *testing.T) {
	env := testutil.NewEnv(t)
	profName := mustEnableAcmeProfile(t, env, "acme-attest-bad-root")
	udid := "00008101-untrusted"

	client, _ := bootstrapAcmeAccount(t, env, profName)
	thumb := mustThumbprint(t, client.jwk)
	_ = env.DB.Model(&models.Profile{}).Where("name = ?", profName).
		Updates(map[string]any{
			"acme_allowed_identifiers": "permanent-identifier",
			"acme_attestation_formats": "apple",
		})
	var acct models.AcmeAccount
	_ = env.DB.Where("key_thumbprint = ?", thumb).First(&acct).Error
	kid := acct.KeyID

	createURL := newOrderURL(env, profName)
	jws := client.signed(createURL, modeKID, kid, client.fetchNonce(), map[string]any{
		"identifiers": []map[string]string{{"type": "permanent-identifier", "value": udid}},
	})
	cr := client.post(t, createURL, jws)
	defer cr.Body.Close()
	var ob struct{ Authorizations []string }
	_ = json.NewDecoder(cr.Body).Decode(&ob)

	azJWS := client.signed(ob.Authorizations[0], modeKID, kid, client.fetchNonce(), "")
	azResp := client.post(t, ob.Authorizations[0], azJWS)
	defer azResp.Body.Close()
	var ab struct {
		Challenges []struct{ URL, Token string }
	}
	_ = json.NewDecoder(azResp.Body).Decode(&ab)
	chall := ab.Challenges[0]

	digest := sha256.Sum256([]byte(chall.Token + "." + thumb))
	fix := buildAppleFixture(t, digest[:], udid, "")
	// Intentionally DO NOT install fix.rootPEM. The profile column
	// stays empty -> resolveAttestationRoots errors out -> validator
	// rejects.
	chJWS := client.signed(chall.URL, modeKID, kid, client.fetchNonce(), map[string]any{
		"attObj": base64.RawURLEncoding.EncodeToString(fix.chainCBOR),
	})
	chResp := client.post(t, chall.URL, chJWS)
	defer chResp.Body.Close()

	var ch models.AcmeChallenge
	_ = env.DB.Where("token = ?", chall.Token).First(&ch).Error
	if ch.Status != "invalid" {
		t.Errorf("challenge.status=%q want invalid", ch.Status)
	}
}
