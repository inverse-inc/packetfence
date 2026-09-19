package acme

import (
	"crypto/x509"
	"errors"
)

// appleEnterpriseAttestationRootPEM is Apple's "Apple Enterprise
// Attestation Root CA", the root that signs the per-device attestation
// chain Apple's managed-device flow produces for device-attest-01
// (RFC 9447). P-384, self-signed, valid 2022-02-16 → 2047-02-20.
//
// Downloaded from
// https://www.apple.com/certificateauthority/Apple_Enterprise_Attestation_Root_CA.pem
// and cross-checked against the copy smallstep/certificates embeds
// for the same purpose; both have SHA-256 fingerprint
//
//	CC:F5:9E:F8:FC:B3:01:7D:97:F8:B5:FA:6F:A9:0E:7A:3F:92:83:F7:6B:55:AC:6C:F6:ED:A8:B8:B9:49:F0:5B
//
// which TestAppleAttestationRoot_Fingerprint pins. Operators can still
// override it per profile through Profile.AcmeAttestationRoots (for a
// future Apple root, or a lab attestation chain of their own); the
// override replaces this root rather than adding to it.
const appleEnterpriseAttestationRootPEM = `-----BEGIN CERTIFICATE-----
MIICJDCCAamgAwIBAgIUQsDCuyxyfFxeq/bxpm8frF15hzcwCgYIKoZIzj0EAwMw
UTEtMCsGA1UEAwwkQXBwbGUgRW50ZXJwcmlzZSBBdHRlc3RhdGlvbiBSb290IENB
MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzAeFw0yMjAyMTYxOTAx
MjRaFw00NzAyMjAwMDAwMDBaMFExLTArBgNVBAMMJEFwcGxlIEVudGVycHJpc2Ug
QXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UE
BhMCVVMwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAAT6Jigq+Ps9Q4CoT8t8q+UnOe2p
oT9nRaUfGhBTbgvqSGXPjVkbYlIWYO+1zPk2Sz9hQ5ozzmLrPmTBgEWRcHjA2/y7
7GEicps9wn2tj+G89l3INNDKETdxSPPIZpPj8VmjQjBAMA8GA1UdEwEB/wQFMAMB
Af8wHQYDVR0OBBYEFPNqTQGd8muBpV5du+UIbVbi+d66MA4GA1UdDwEB/wQEAwIB
BjAKBggqhkjOPQQDAwNpADBmAjEA1xpWmTLSpr1VH4f8Ypk8f3jMUKYz4QPG8mL5
8m9sX/b2+eXpTv2pH4RZgJjucnbcAjEA4ZSB6S45FlPuS/u4pTnzoz632rA+xW/T
ZwFEh9bhKjJ+5VQ9/Do1os0u3LEkgN/r
-----END CERTIFICATE-----
`

// resolveAttestationRoots returns the x509.CertPool the validator
// should trust for device-attest-01 chains under the given profile.
// Order of precedence:
//
//  1. Profile.AcmeAttestationRoots (PEM blob set by the operator).
//  2. appleEnterpriseAttestationRootPEM (embedded Apple root).
//
// Returns an error if neither source yields a usable cert — the
// validator must refuse rather than fall through to an empty pool,
// which would accept any chain.
func resolveAttestationRoots(profileOverride string) (*x509.CertPool, error) {
	pool := x509.NewCertPool()
	if profileOverride != "" {
		if !pool.AppendCertsFromPEM([]byte(profileOverride)) {
			return nil, errors.New("Profile.AcmeAttestationRoots did not contain any PEM certificate")
		}
		return pool, nil
	}
	if appleEnterpriseAttestationRootPEM != "" {
		if !pool.AppendCertsFromPEM([]byte(appleEnterpriseAttestationRootPEM)) {
			return nil, errors.New("embedded Apple attestation root PEM is malformed")
		}
		return pool, nil
	}
	return nil, errors.New("no Apple attestation root configured; set Profile.AcmeAttestationRoots")
}
