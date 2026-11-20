package models

import (
	"errors"
	"time"

	"gorm.io/gorm"
)

// AcmeOrder is an RFC 8555 §7.1.3 "order" object — the device's request
// to be issued one or more certs. State machine:
//
//	pending  → ready  → processing → valid
//	      \         \           \
//	       └─────────┴───────────┴── invalid
//
// Transitions:
//   - pending → ready: all referenced AcmeAuthz rows reached "valid"
//   - ready → processing: client POSTed /finalize with a CSR
//   - processing → valid: cert was issued (CertSerialNumber is set)
//   - * → invalid: any failure (challenge timeout, CSR rejected, etc.)
//
// Identifiers and Error are JSON-encoded; we keep them in the DB as
// the raw payload bytes to avoid lossy round-tripping through Go types.
type AcmeOrder struct {
	ID        uint           `gorm:"primarykey"`
	CreatedAt time.Time      `json:"-"`
	UpdatedAt time.Time      `json:"-"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`

	AccountID uint      `gorm:"index;not null"`
	Status    string    `gorm:"size:16;default:'pending'"`
	ExpiresAt time.Time `gorm:"index"`
	NotBefore time.Time
	NotAfter  time.Time

	// Identifiers is the JSON-encoded RFC 8555 §7.1.3 identifiers
	// array, e.g. [{"type":"dns","value":"a.example"}]. Kept opaque
	// here; parsing/validation lives in the acme package.
	Identifiers string `gorm:"type:text"`
	// AuthzIDs is a comma-separated list of AcmeAuthz primary keys
	// referenced by this order; small and bounded by identifier count.
	AuthzIDs string `gorm:"type:text"`
	// FinalizeURL and CertSerialNumber are populated through the state
	// transitions and exposed in /order/{id} responses.
	FinalizeURL      string `gorm:"-"`
	CertSerialNumber string `gorm:"size:80;index"`
	Error            string `gorm:"type:text"` // ACME problem document JSON
}

func (AcmeOrder) TableName() string { return "pki_acme_orders" }

// CheckACMEDuplicateCN checks the template's duplicate-CN policy for an
// ACME finalize without revoking anything. Returns an error when issuance
// must be refused, nil when it is allowed. The caller must call
// RevokeSupersededCN(db, prof, cn, newCert.ID) after the new cert is
// successfully persisted, so a failed signing cannot leave the device
// with only a revoked certificate.
func CheckACMEDuplicateCN(db *gorm.DB, prof *Profile, cn string) error {
	allowTime := prof.DaysBeforeRenewal
	if prof.AllowDuplicatedCN == 1 {
		if prof.MaximumDuplicatedCN == 0 {
			return nil
		}
		var certifs []Cert
		certDB := db.Where("cn = ? AND profile_name = ?", cn, prof.Name).Find(&certifs)
		if certDB.Error != nil {
			return nil
		}
		willBeRevoked := 0
		for i := range certifs {
			if certExpiresWithin(&certifs[i], allowTime) {
				willBeRevoked++
			}
		}
		if int(certDB.RowsAffected)-willBeRevoked >= prof.MaximumDuplicatedCN {
			return errors.New("Certificate with this Subject already exist: " + cn)
		}
		return nil
	}
	var certif Cert
	certDB := db.Where("Cn = ? AND profile_name = ?", cn, prof.Name).Find(&certif)
	if certDB.Error != nil || certDB.RowsAffected == 0 {
		return nil
	}
	if certExpiresWithin(&certif, allowTime) {
		return nil
	}
	return errors.New("Certificate with this Subject already exist: " + certif.Cn)
}
