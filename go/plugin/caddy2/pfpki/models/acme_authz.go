package models

import (
	"time"

	"gorm.io/gorm"
)

// AcmeAuthz is an RFC 8555 §7.1.4 "authorization" — proof that the
// requesting account controls a single identifier. One authz per
// identifier on an AcmeOrder. State machine:
//
//	pending → valid | invalid | expired | deactivated | revoked
//
// pending → valid when any associated AcmeChallenge becomes valid.
// IdentifierType is one of "dns" | "ip" | "permanent-identifier" per
// the active extensions; Value is the literal identifier value
// (hostname, IP literal, device UDID...).
type AcmeAuthz struct {
	ID        uint           `gorm:"primarykey"`
	CreatedAt time.Time      `json:"-"`
	UpdatedAt time.Time      `json:"-"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`

	AccountID      uint   `gorm:"index;not null"`
	OrderID        uint   `gorm:"index;not null"`
	IdentifierType string `gorm:"size:32"`
	Value          string `gorm:"size:255"`
	Status         string `gorm:"size:16;default:'pending'"`
	ExpiresAt      time.Time `gorm:"index"`
	Wildcard       bool   `gorm:"default:false"`
}

func (AcmeAuthz) TableName() string { return "pki_acme_authzs" }
