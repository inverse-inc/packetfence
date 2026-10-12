package models

import (
	"context"
	"crypto"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"github.com/inverse-inc/go-utils/log"
	"golang.org/x/crypto/ocsp"
	"gorm.io/gorm"
)

// ErrESTPolicy wraps the EST enrollment refusals that come from the
// profile policy (duplicate CN, nothing to re-enroll, …) rather than
// from a malformed request or a server fault.
var ErrESTPolicy = errors.New("EST policy")

// GetESTProfile loads an EST-enabled profile with its CA. An empty name
// selects the first EST-enabled profile, which serves the label-less
// /.well-known/est/<operation> URLs.
func GetESTProfile(db *gorm.DB, name string) (*Profile, error) {
	prof := &Profile{}
	q := db.Preload("Ca").Where("est_enabled = ?", 1)
	if name != "" {
		q = q.Where("name = ?", name)
	}
	if err := q.Order("id").First(prof).Error; err != nil {
		return nil, err
	}
	return prof, nil
}

// IssueESTCert signs an EST (RFC 7030) enrollment request under prof.
//
// The EST password is shared by every device of the profile, so a
// request may only name its own CN: DNS and email SANs must repeat the
// CN, IP and URI SANs are refused.
//
// simpleenroll applies the same duplicate-CN policy as the other issuance
// paths (an existing certificate is superseded only when it is within
// DaysBeforeRenewal of its expiry). simplereenroll renews the live
// certificate of the CN under the profile whose public key is the one of
// the CSR: the CSR signature proves the client holds that key, so it can
// only renew its own certificate (a rekey goes through simpleenroll). The
// new certificate is issued first and the renewed one is then revoked as
// superseded, so a failed re-enrollment never leaves the client without a
// certificate. The client has already been authenticated by the EST
// handler.
func IssueESTCert(db *gorm.DB, ctx context.Context, prof Profile, csr *x509.CertificateRequest, reenroll bool) (*Cert, error) {
	cn := strings.TrimSpace(csr.Subject.CommonName)
	if cn == "" {
		return nil, fmt.Errorf("%w: the CSR has no common name", ErrESTPolicy)
	}
	if err := checkESTNames(csr, cn); err != nil {
		return nil, err
	}

	if !reenroll {
		if _, err := revokeNeeded(cn, &prof, prof.DaysBeforeRenewal, db); err != nil {
			return nil, fmt.Errorf("%w: %s", ErrESTPolicy, err.Error())
		}
		return issueFromCSR(db, ctx, prof, csr, 0)
	}

	previous, err := estCertForKey(db, prof, cn, csr.PublicKey)
	if err != nil {
		return nil, err
	}

	cert, err := issueFromCSR(db, ctx, prof, csr, 0)
	if err != nil {
		return nil, err
	}

	previous.DB = db
	previous.Ctx = ctx
	if _, err := previous.Revoke(map[string]string{
		"id":     strconv.Itoa(int(previous.ID)),
		"reason": strconv.Itoa(ocsp.Superseded),
	}); err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("EST: unable to revoke superseded certificate %d (CN %q): %s", previous.ID, cn, err))
	}
	return cert, nil
}

// checkESTNames refuses the subject alternative names an EST client may
// not ask for: anything but its CN.
func checkESTNames(csr *x509.CertificateRequest, cn string) error {
	for _, name := range csr.DNSNames {
		if !strings.EqualFold(name, cn) {
			return fmt.Errorf("%w: DNS name %q differs from the common name", ErrESTPolicy, name)
		}
	}
	for _, mail := range csr.EmailAddresses {
		if !strings.EqualFold(mail, cn) {
			return fmt.Errorf("%w: email address %q differs from the common name", ErrESTPolicy, mail)
		}
	}
	if len(csr.IPAddresses) > 0 {
		return fmt.Errorf("%w: IP address subject alternative names are not allowed", ErrESTPolicy)
	}
	if len(csr.URIs) > 0 {
		return fmt.Errorf("%w: URI subject alternative names are not allowed", ErrESTPolicy)
	}
	return nil
}

// estCertForKey returns the live certificate with the given CN under
// prof whose public key is pub.
func estCertForKey(db *gorm.DB, prof Profile, cn string, pub crypto.PublicKey) (*Cert, error) {
	var previous []Cert
	if err := db.Where("cn = ? AND profile_name = ?", cn, prof.Name).Find(&previous).Error; err != nil {
		return nil, err
	}
	if len(previous) == 0 {
		return nil, fmt.Errorf("%w: no certificate with CN %q to re-enroll under profile %q", ErrESTPolicy, cn, prof.Name)
	}
	for i := range previous {
		block, _ := pem.Decode([]byte(previous[i].Cert))
		if block == nil {
			continue
		}
		cert, err := x509.ParseCertificate(block.Bytes)
		if err != nil {
			continue
		}
		if sameKey(cert.PublicKey, pub) == nil {
			return &previous[i], nil
		}
	}
	return nil, fmt.Errorf("%w: the CSR key is not the key of the certificate with CN %q under profile %q; use simpleenroll to enroll a new key", ErrESTPolicy, cn, prof.Name)
}
