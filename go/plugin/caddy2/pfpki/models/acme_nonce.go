package models

import (
	"time"

	"gorm.io/gorm"
)

// AcmeNonce is a single-use anti-replay token (RFC 8555 §6.5). Issued
// by the /new-nonce handler and consumed by exactly one subsequent JWS
// request. Rows are deleted on consume and swept by the
// pki_acme_state_cleanup pfcron after ExpiresAt — both paths are
// required because not every issued nonce is consumed.
//
// Token doubles as the lookup key and the value sent over the wire, so
// it must be unguessable; the issuer uses crypto/rand for that.
type AcmeNonce struct {
	ID        uint           `gorm:"primarykey"`
	CreatedAt time.Time      `json:"-"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`

	Token     string    `gorm:"size:64;uniqueIndex:acme_nonce_token"`
	ExpiresAt time.Time `gorm:"index"`
}

func (AcmeNonce) TableName() string { return "pki_acme_nonces" }
