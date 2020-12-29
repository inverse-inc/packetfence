package gormmodels

import (
	"crypto/x509"
	"time"

	"github.com/jinzhu/gorm"
)

type (
	Type int
	// CA struct
	CA struct {
		gorm.Model
		Cn               string                  `json:"cn,omitempty" gorm:"UNIQUE"`
		Mail             string                  `json:"mail,omitempty" gorm:"INDEX:mail"`
		Organisation     string                  `json:"organisation,omitempty" gorm:"INDEX:organisation"`
		Country          string                  `json:"country,omitempty"`
		State            string                  `json:"state,omitempty"`
		Locality         string                  `json:"locality,omitempty"`
		StreetAddress    string                  `json:"street_address,omitempty"`
		PostalCode       string                  `json:"postal_code,omitempty"`
		KeyType          *Type                   `json:"key_type,omitempty,string"`
		KeySize          int                     `json:"key_size,omitempty,string"`
		Digest           x509.SignatureAlgorithm `json:"digest,omitempty,string"`
		KeyUsage         *string                 `json:"key_usage,omitempty"`
		ExtendedKeyUsage *string                 `json:"extended_key_usage,omitempty"`
		Days             int                     `json:"days,omitempty,string"`
		Key              string                  `json:"-" gorm:"type:longtext"`
		Cert             string                  `json:"cert,omitempty" gorm:"type:longtext"`
		IssuerKeyHash    string                  `json:"issuer_key_hash,omitempty" gorm:"UNIQUE_INDEX"`
		IssuerNameHash   string                  `json:"issuer_name_hash,omitempty" gorm:"UNIQUE_INDEX"`
	}

	// Profile struct
	Profile struct {
		gorm.Model
		Name             string                  `json:"name" gorm:"UNIQUE"`
		Ca               CA                      `json:"-"`
		CaID             uint                    `json:"ca_id,omitempty,string" gorm:"INDEX:ca_id"`
		CaName           string                  `json:"ca_name,omitempty" gorm:"INDEX:ca_name"`
		Validity         int                     `json:"validity,omitempty,string"`
		KeyType          *Type                   `json:"key_type,omitempty,string"`
		KeySize          int                     `json:"key_size,omitempty,string"`
		Digest           x509.SignatureAlgorithm `json:"digest,omitempty,string"`
		KeyUsage         *string                 `json:"key_usage,omitempty"`
		ExtendedKeyUsage *string                 `json:"extended_key_usage,omitempty"`
		P12MailPassword  int                     `json:"p12_mail_password,omitempty,string"`
		P12MailSubject   string                  `json:"p12_mail_subject,omitempty"`
		P12MailFrom      string                  `json:"p12_mail_from,omitempty"`
		P12MailHeader    string                  `json:"p12_mail_header,omitempty"`
		P12MailFooter    string                  `json:"p12_mail_footer,omitempty"`
	}

	// Cert struct
	Cert struct {
		gorm.Model
		Cn            string    `json:"cn,omitempty" gorm:"UNIQUE"`
		Mail          string    `json:"mail,omitempty" gorm:"INDEX:mail"`
		Ca            CA        `json:"-"`
		CaID          uint      `json:"ca_id,omitempty" gorm:"INDEX:ca_id"`
		CaName        string    `json:"ca_name,omitempty" gorm:"INDEX:ca_name"`
		StreetAddress string    `json:"street_address,omitempty"`
		Organisation  string    `json:"organisation,omitempty" gorm:"INDEX:organisation"`
		Country       string    `json:"country,omitempty"`
		State         string    `json:"state,omitempty"`
		Locality      string    `json:"locality,omitempty"`
		PostalCode    string    `json:"postal_code,omitempty"`
		Key           string    `json:"-" gorm:"type:longtext"`
		Cert          string    `json:"cert,omitempty" gorm:"type:longtext"`
		Profile       Profile   `json:"-"`
		ProfileID     uint      `json:"profile_id,omitempty,string" gorm:"INDEX:profile_id"`
		ProfileName   string    `json:"profile_name,omitempty" gorm:"INDEX:profile_name"`
		ValidUntil    time.Time `json:"valid_until,omitempty" gorm:"INDEX:valid_until"`
		Date          time.Time `json:"date,omitempty" gorm:"default:CURRENT_TIMESTAMP"`
		SerialNumber  string    `json:"serial_number,omitempty"`
	}

	// RevokedCert struct
	RevokedCert struct {
		gorm.Model
		Cn            string    `json:"cn,omitempty" gorm:"INDEX:cn"`
		Mail          string    `json:"mail,omitempty" gorm:"INDEX:mail"`
		Ca            CA        `json:"-"`
		CaID          uint      `json:"ca_id,omitempty" gorm:"INDEX:ca_id"`
		CaName        string    `json:"ca_name,omitempty" gorm:"INDEX:ca_name"`
		StreetAddress string    `json:"street_address,omitempty"`
		Organisation  string    `json:"organisation,omitempty" gorm:"INDEX:organisation"`
		Country       string    `json:"country,omitempty"`
		State         string    `json:"state,omitempty"`
		Locality      string    `json:"locality,omitempty"`
		PostalCode    string    `json:"postal_code,omitempty"`
		Key           string    `json:"-" gorm:"type:longtext"`
		Cert          string    `json:"cert,omitempty" gorm:"type:longtext"`
		Profile       Profile   `json:"-"`
		ProfileID     uint      `json:"profile_id,omitempty" gorm:"INDEX:profile_id"`
		ProfileName   string    `json:"profile_name,omitempty" gorm:"INDEX:profile_name"`
		ValidUntil    time.Time `json:"valid_until,omitempty" gorm:"INDEX:valid_until"`
		Date          time.Time `json:"date,omitempty" gorm:"default:CURRENT_TIMESTAMP"`
		SerialNumber  string    `json:"serial_number,omitempty"`
		Revoked       time.Time `json:"revoked,omitempty" gorm:"INDEX:revoked"`
		CRLReason     int       `json:"crl_reason,omitempty" gorm:"INDEX:crl_reason"`
	}
)
