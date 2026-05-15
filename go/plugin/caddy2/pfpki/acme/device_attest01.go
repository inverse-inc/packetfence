package acme

import (
	"crypto/sha256"
	"crypto/x509"
	"encoding/asn1"
	"errors"
	"fmt"
	"strings"

	"github.com/fxamacker/cbor/v2"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
)

// Apple-published OIDs the attestation leaf cert carries as
// x509.Extension values. Layout per Apple Platform Deployment
// (managed-device attestation reference):
//
//   1.2.840.113635.100.8.2   nonce         (DER OCTET STRING wrapped
//                                            in a SEQUENCE)
//   1.2.840.113635.100.8.3   device UDID   (UTF8String)
//   1.2.840.113635.100.8.5   device serial (UTF8String)
//   1.2.840.113635.100.8.10  OS version    (UTF8String)
//
// We don't actually need the OS version for the protocol — we leave it
// extractable so operators can audit-log it later without a second
// parse.
var (
	oidAppleAttestNonce      = asn1.ObjectIdentifier{1, 2, 840, 113635, 100, 8, 2}
	oidAppleAttestUDID       = asn1.ObjectIdentifier{1, 2, 840, 113635, 100, 8, 3}
	oidAppleAttestSerial     = asn1.ObjectIdentifier{1, 2, 840, 113635, 100, 8, 5}
	oidAppleAttestOSVersion  = asn1.ObjectIdentifier{1, 2, 840, 113635, 100, 8, 10}
)

// appleAttestationObject is the WebAuthn-style CBOR shape Apple's
// client posts as the challenge payload. We only care about the
// "apple" format here; "step", "tpm" etc. are out of scope per the
// plan's Phase 2 declaration.
//
// authData isn't needed for the Apple flow (Apple's nonce + UDID live
// on the leaf cert extensions, not in authData) but we keep the field
// so a malformed payload still decodes deterministically.
type appleAttestationObject struct {
	Format       string                 `cbor:"fmt"`
	AttStatement appleAttestationStmt   `cbor:"attStmt"`
	AuthData     []byte                 `cbor:"authData"`
}

type appleAttestationStmt struct {
	// x5c is the device attestation chain, leaf-first; we verify it
	// against the configured Apple root.
	X5C [][]byte `cbor:"x5c"`
}

// deviceInfo carries the bits the validator extracts from a valid
// attestation chain. UDID is the post-iOS-16 stable identifier; older
// devices may only provide Serial. We accept either for matching the
// order's permanent-identifier value.
type deviceInfo struct {
	UDID        string
	Serial      string
	OSVersion   string
	Leaf        *x509.Certificate // the attestation leaf cert
}

// deviceAttest01Validate is the device-attest-01 (RFC 9447) replacement
// for http01Validate. The payload bytes come from the
// challengeByIDHandler's trigger path; they are the CBOR-encoded
// attestation object the device posts.
//
// Validation steps, all of which must pass:
//
//   1. CBOR-decode and confirm the format is "apple".
//   2. Parse the x5c chain (leaf-first).
//   3. Verify the chain against the configured Apple root (per
//      profile, or the embedded slot).
//   4. Extract the Apple OIDs from the leaf cert's extensions.
//   5. Confirm the nonce equals SHA-256(challenge.token ||
//      accountThumbprint) per RFC 9447 §3.
//   6. Confirm the order's permanent-identifier value matches the
//      device's UDID (preferred) or Serial.
//
// On any failure returns a Go error whose string can go straight into
// an ACME problem document.
func deviceAttest01Validate(prof models.Profile, attestation []byte, challengeToken, accountThumbprint, expectedIdentifier string) error {
	if len(attestation) == 0 {
		return errors.New("device-attest-01: empty attestation payload")
	}

	var obj appleAttestationObject
	if err := cbor.Unmarshal(attestation, &obj); err != nil {
		return fmt.Errorf("device-attest-01: CBOR decode: %w", err)
	}
	if obj.Format != "apple" {
		return fmt.Errorf("device-attest-01: unsupported fmt %q (only apple)", obj.Format)
	}
	if len(obj.AttStatement.X5C) == 0 {
		return errors.New("device-attest-01: attStmt.x5c is empty")
	}

	leaf, err := x509.ParseCertificate(obj.AttStatement.X5C[0])
	if err != nil {
		return fmt.Errorf("device-attest-01: parse leaf: %w", err)
	}
	intermediates := x509.NewCertPool()
	for _, der := range obj.AttStatement.X5C[1:] {
		c, err := x509.ParseCertificate(der)
		if err != nil {
			return fmt.Errorf("device-attest-01: parse intermediate: %w", err)
		}
		intermediates.AddCert(c)
	}

	roots, err := resolveAttestationRoots(prof.AcmeAttestationRoots)
	if err != nil {
		return err
	}
	// The Apple attestation chain isn't intended for server-auth /
	// client-auth use; allow Any so x509.Verify doesn't reject on EKU.
	if _, err := leaf.Verify(x509.VerifyOptions{
		Roots:         roots,
		Intermediates: intermediates,
		KeyUsages:     []x509.ExtKeyUsage{x509.ExtKeyUsageAny},
	}); err != nil {
		return fmt.Errorf("device-attest-01: verify chain: %w", err)
	}

	dev, err := extractAppleDevice(leaf)
	if err != nil {
		return err
	}

	// Nonce binding (RFC 9447 §3): nonce in the extension MUST equal
	// SHA-256(token || thumbprint). Apple sometimes adds a wrapping
	// ASN.1 layer; extractAppleDevice already unwraps it before
	// returning the raw 32-byte digest.
	expectedNonce := sha256.Sum256([]byte(challengeToken + "." + accountThumbprint))
	if !constantTimeEqual(dev.nonce, expectedNonce[:]) {
		return errors.New("device-attest-01: nonce does not match SHA-256(token.thumbprint)")
	}

	// Identifier match. The order identifier is the
	// `permanent-identifier`'s value; the device may supply either
	// UDID (preferred) or Serial. Either is acceptable.
	want := strings.TrimSpace(expectedIdentifier)
	if want == "" {
		return errors.New("device-attest-01: order has empty permanent-identifier")
	}
	if dev.UDID == want || dev.Serial == want {
		return nil
	}
	return fmt.Errorf("device-attest-01: identifier mismatch: order=%q udid=%q serial=%q",
		want, dev.UDID, dev.Serial)
}

// extractedDevice combines deviceInfo with the parsed nonce extension
// so the validator can do the constant-time compare without exposing
// the raw extension bytes everywhere.
type extractedDevice struct {
	deviceInfo
	nonce []byte
}

// extractAppleDevice walks the leaf cert's extensions, pulls the four
// Apple OID values we care about, and unwraps the ASN.1 framing Apple
// puts around the nonce extension.
func extractAppleDevice(leaf *x509.Certificate) (extractedDevice, error) {
	out := extractedDevice{deviceInfo: deviceInfo{Leaf: leaf}}
	for _, ext := range leaf.Extensions {
		switch {
		case ext.Id.Equal(oidAppleAttestNonce):
			n, err := unwrapAppleNonce(ext.Value)
			if err != nil {
				return out, fmt.Errorf("device-attest-01: parse nonce ext: %w", err)
			}
			out.nonce = n
		case ext.Id.Equal(oidAppleAttestUDID):
			s, err := unwrapAppleUTF8(ext.Value)
			if err == nil {
				out.UDID = s
			}
		case ext.Id.Equal(oidAppleAttestSerial):
			s, err := unwrapAppleUTF8(ext.Value)
			if err == nil {
				out.Serial = s
			}
		case ext.Id.Equal(oidAppleAttestOSVersion):
			s, err := unwrapAppleUTF8(ext.Value)
			if err == nil {
				out.OSVersion = s
			}
		}
	}
	if len(out.nonce) == 0 {
		return out, errors.New("device-attest-01: leaf cert has no Apple nonce extension")
	}
	if out.UDID == "" && out.Serial == "" {
		return out, errors.New("device-attest-01: leaf cert exposes neither UDID nor serial")
	}
	return out, nil
}

// unwrapAppleNonce strips the ASN.1 SEQUENCE { OCTET STRING } wrapper
// Apple puts around the 32-byte SHA-256 digest, and also accepts a
// bare OCTET STRING for forward compatibility / test fixtures.
func unwrapAppleNonce(raw []byte) ([]byte, error) {
	// Try SEQUENCE { OCTET STRING }.
	var wrapped struct {
		Nonce []byte `asn1:"tag:4"`
	}
	if _, err := asn1.Unmarshal(raw, &wrapped); err == nil && len(wrapped.Nonce) > 0 {
		return wrapped.Nonce, nil
	}
	// Fall back to a bare OCTET STRING.
	var bare []byte
	if _, err := asn1.Unmarshal(raw, &bare); err == nil && len(bare) > 0 {
		return bare, nil
	}
	// Last resort: assume the extension value is already the raw
	// digest. Apple has been known to ship both shapes across iOS
	// releases.
	if len(raw) == sha256.Size {
		return raw, nil
	}
	return nil, errors.New("nonce extension is neither SEQUENCE{OCTETSTRING} nor bare OCTET STRING nor 32-byte raw digest")
}

// unwrapAppleUTF8 decodes an Apple UTF8String extension value.
// Tolerates the bare-bytes form some early iOS releases emitted.
func unwrapAppleUTF8(raw []byte) (string, error) {
	var s string
	if _, err := asn1.Unmarshal(raw, &s); err == nil && s != "" {
		return s, nil
	}
	// Bare bytes: treat as UTF-8 directly.
	if len(raw) > 0 {
		return string(raw), nil
	}
	return "", errors.New("empty extension")
}

// constantTimeEqual is a length-tolerant timing-safe compare. The two
// byte slices are equal iff they have the same length and identical
// content. Used for the nonce check where a leaked timing oracle
// would let an attacker recover the digest byte-by-byte.
func constantTimeEqual(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	var v byte
	for i := range a {
		v |= a[i] ^ b[i]
	}
	return v == 0
}
