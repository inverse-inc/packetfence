package models

import (
	"time"

	"gorm.io/gorm"
)

// AcmeChallenge is an RFC 8555 §7.1.5 "challenge" — one mechanism for
// proving control over an authz's identifier. Type values today:
//
//	"http-01"            RFC 8555 §8.3
//	"dns-01"             RFC 8555 §8.4 (gated by profile policy)
//	"device-attest-01"   RFC 9447, used by Apple's managed-device flow
//
// Token is the per-challenge random string the client signs with its
// account key (the "key authorization") to prove possession. The
// server publishes the token in responses; only the device sees the
// signed key authorization on its side of the proof exchange.
type AcmeChallenge struct {
	ID        uint           `gorm:"primarykey"`
	CreatedAt time.Time      `json:"-"`
	UpdatedAt time.Time      `json:"-"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`

	AuthzID    uint   `gorm:"index;not null"`
	Type       string `gorm:"size:32"`
	Token      string `gorm:"size:64;index"`
	Status     string `gorm:"size:16;default:'pending'"`
	Validated  time.Time
	Error      string `gorm:"type:text"` // ACME problem document JSON on failure
	RetryAfter time.Time
}

func (AcmeChallenge) TableName() string { return "pki_acme_challenges" }
