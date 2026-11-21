package models

import (
	"time"

	"gorm.io/gorm"
)

// AcmeAccount is an RFC 8555 §7.1.2 "account" object persisted across
// requests. Keyed by KeyID (the account URL, which clients send back
// as the JWS `kid`) so JWS validation can look it up directly from the
// request's `kid` field. ProfileID scopes the account to a single
// pfpki profile, which acts as the ACME "provisioner" boundary.
//
// One row per (profile, public-key) pair; key rollover replaces the
// JWK + KeyThumbprint in place, KeyID (the account URL) stays.
type AcmeAccount struct {
	ID        uint           `gorm:"primarykey"`
	CreatedAt time.Time      `json:"-"`
	UpdatedAt time.Time      `json:"-"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`

	ProfileID uint   `json:"-" gorm:"index;not null;uniqueIndex:acme_account_profile_thumbprint,priority:1"`
	// KeyID is the lookup key for JWS `kid` (a URL pointing at this
	// account on this server). KeyThumbprint is what the new-account
	// handler looks existing keys up by; it is unique per profile so two
	// racing new-account requests for one key can't create two accounts.
	KeyID         string `json:"key_id" gorm:"size:256;uniqueIndex:acme_account_keyid"`
	KeyThumbprint string `json:"-"      gorm:"size:64;index:acme_account_thumbprint;uniqueIndex:acme_account_profile_thumbprint,priority:2"`
	// JWK is the account's public key, JSON-encoded per RFC 7517 so it
	// can be marshaled into JWS verification calls verbatim.
	JWK     string `json:"-" gorm:"type:longtext"`
	Status  string `json:"status" gorm:"size:16;default:'valid'"` // valid | deactivated | revoked
	Contact string `json:"-"      gorm:"type:text"`               // JSON-encoded []string
	// ExternalAccountKeyID is the KID of the AcmeExternalAccountKey row
	// that authorised the new-account request (empty for accounts
	// created without EAB, which is profile-policy-controlled).
	ExternalAccountKeyID string `json:"-" gorm:"size:64;index"`
	OrdersURL            string `json:"orders,omitempty" gorm:"-"`
	ExpiresAt            time.Time `json:"-"`
}

// TableName pins to the pfpki convention (pki_<plural>).
func (AcmeAccount) TableName() string { return "pki_acme_accounts" }
