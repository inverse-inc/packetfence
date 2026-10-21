package models

import (
	"time"

	"gorm.io/gorm"
)

// AcmeExternalAccountKey backs RFC 8555 §7.3.4 external-account
// binding. The admin mints a (KeyID, HMACKey) pair per profile; the
// device's MDM profile carries them, and the device's /new-account
// request must include an outer JWS signed with HMACKey under that
// KeyID. The handler validates that signature here.
//
// HMACKey is stored URL-safe base64 (matching what the client sees)
// rather than raw bytes, so the row contents round-trip cleanly into
// admin UIs without re-encoding. Reference (in profile UI) is a
// human-readable label like "lab-fleet-2026Q2"; not used by the
// protocol.
type AcmeExternalAccountKey struct {
	ID        uint           `gorm:"primarykey"`
	CreatedAt time.Time      `json:"-"`
	UpdatedAt time.Time      `json:"-"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`

	ProfileID uint   `gorm:"index;not null"`
	KeyID     string `gorm:"size:64;uniqueIndex:acme_eab_keyid"`
	HMACKey   string `gorm:"size:128"`
	Reference string `gorm:"size:128"`
	// BoundAccountID, when non-zero, pins this EAB key to a single
	// AcmeAccount — used after the first /new-account that consumes
	// it, so the same key can't bind a different account later.
	BoundAccountID uint      `gorm:"index"`
	BoundAt        time.Time
}

func (AcmeExternalAccountKey) TableName() string { return "pki_acme_eab_keys" }
