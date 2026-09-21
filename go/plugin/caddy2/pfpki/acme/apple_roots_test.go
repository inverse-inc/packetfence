package acme

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/pem"
	"strings"
	"testing"
)

// TestAppleAttestationRoot_Fingerprint pins the embedded Apple
// Enterprise Attestation Root CA to the fingerprint of the copy Apple
// publishes (and smallstep embeds), so a stray edit or a swapped cert
// can't silently change what device-attest-01 trusts.
func TestAppleAttestationRoot_Fingerprint(t *testing.T) {
	const want = "ccf59ef8fcb3017d97f8b5fa6fa90e7a3f9283f76b55ac6cf6eda8b8b949f05b"
	block, _ := pem.Decode([]byte(appleEnterpriseAttestationRootPEM))
	if block == nil {
		t.Fatalf("embedded root is not PEM")
	}
	sum := sha256.Sum256(block.Bytes)
	if got := hex.EncodeToString(sum[:]); got != want {
		t.Fatalf("embedded Apple root fingerprint = %s, want %s", got, want)
	}
	pool, err := resolveAttestationRoots("")
	if err != nil {
		t.Fatalf("resolveAttestationRoots(\"\"): %v", err)
	}
	if pool == nil {
		t.Fatalf("nil pool for the embedded root")
	}
	if _, err := resolveAttestationRoots("not a pem"); err == nil || !strings.Contains(err.Error(), "PEM") {
		t.Fatalf("bad override must be refused, got %v", err)
	}
}
