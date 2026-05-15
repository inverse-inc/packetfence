package acme

import (
	"crypto/x509"
	"errors"
)

// appleEnterpriseAttestationRootPEM is the slot for Apple's "Apple
// Enterprise Attestation Root CA" — the root that signs the per-device
// attestation chain Apple's managed-device flow produces for
// device-attest-01 (RFC 9447).
//
// The real PEM lives on Apple's certificate-authority page at
// https://www.apple.com/certificateauthority/. We intentionally leave
// the constant empty here so the build doesn't ship an unverified copy
// of someone else's cert in our source tree. Operators have two
// options:
//
//   1. Paste the verified PEM into the per-profile
//      Profile.AcmeAttestationRoots column (preferred — explicit and
//      auditable per provisioner).
//   2. Replace this constant in a follow-up commit after verifying
//      against Apple's published fingerprint.
//
// resolveAttestationRoots below honors (1) first, falls back to (2).
const appleEnterpriseAttestationRootPEM = ""

// resolveAttestationRoots returns the x509.CertPool the validator
// should trust for device-attest-01 chains under the given profile.
// Order of precedence:
//
//   1. Profile.AcmeAttestationRoots (PEM blob set by the operator).
//   2. appleEnterpriseAttestationRootPEM (embedded; empty until
//      the operator paths above are validated).
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
