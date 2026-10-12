package models

import (
	"context"
	"crypto/x509"
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
// simpleenroll applies the same duplicate-CN policy as the other issuance
// paths (an existing certificate is superseded only when it is within
// DaysBeforeRenewal of its expiry). simplereenroll requires a certificate
// with the same CN under the profile; the new certificate is issued first
// and the previous ones are then revoked as superseded, so a failed
// re-enrollment never leaves the client without a certificate. The client
// has already been authenticated by the EST handler.
func IssueESTCert(db *gorm.DB, ctx context.Context, prof Profile, csr *x509.CertificateRequest, reenroll bool) (*Cert, error) {
	cn := strings.TrimSpace(csr.Subject.CommonName)
	if cn == "" {
		return nil, fmt.Errorf("%w: the CSR has no common name", ErrESTPolicy)
	}

	if !reenroll {
		if _, err := revokeNeeded(cn, &prof, prof.DaysBeforeRenewal, db); err != nil {
			return nil, fmt.Errorf("%w: %s", ErrESTPolicy, err.Error())
		}
		return issueFromCSR(db, ctx, prof, csr, 0)
	}

	var previous []Cert
	if err := db.Where("cn = ? AND profile_name = ?", cn, prof.Name).Find(&previous).Error; err != nil {
		return nil, err
	}
	if len(previous) == 0 {
		return nil, fmt.Errorf("%w: no certificate with CN %q to re-enroll under profile %q", ErrESTPolicy, cn, prof.Name)
	}

	cert, err := issueFromCSR(db, ctx, prof, csr, 0)
	if err != nil {
		return nil, err
	}

	for i := range previous {
		previous[i].DB = db
		previous[i].Ctx = ctx
		if _, err := previous[i].Revoke(map[string]string{
			"id":     strconv.Itoa(int(previous[i].ID)),
			"reason": strconv.Itoa(ocsp.Superseded),
		}); err != nil {
			log.LoggerWContext(ctx).Error(fmt.Sprintf("EST: unable to revoke superseded certificate %d (CN %q): %s", previous[i].ID, cn, err))
		}
	}
	return cert, nil
}
