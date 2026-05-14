package models

import (
	"context"
	"crypto/x509"
	"strconv"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/cloud"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	_ "gorm.io/driver/mysql"
	"gorm.io/gorm"
)

type (
	// CA struct
	CA struct {
		ID                   uint                    `gorm:"primarykey"`
		CreatedAt            time.Time               `json:"-"`
		UpdatedAt            time.Time               `json:"-"`
		DeletedAt            gorm.DeletedAt          `json:"-" gorm:"index"`
		DB                   *gorm.DB                `json:"-" gorm:"-"`
		Ctx                  context.Context         `json:"-" gorm:"-"`
		Cn                   string                  `json:"cn,omitempty" gorm:"UNIQUE"`
		Mail                 string                  `json:"mail,omitempty" gorm:"INDEX:mail"`
		Organisation         string                  `json:"organisation,omitempty" gorm:"INDEX:organisation"`
		OrganisationalUnit   string                  `json:"organisational_unit,omitempty"`
		Country              string                  `json:"country,omitempty"`
		State                string                  `json:"state,omitempty"`
		Locality             string                  `json:"locality,omitempty"`
		StreetAddress        string                  `json:"street_address,omitempty"`
		PostalCode           string                  `json:"postal_code,omitempty"`
		KeyType              *types.Type             `json:"key_type,omitempty,string"`
		KeySize              int                     `json:"key_size,omitempty,string"`
		Digest               x509.SignatureAlgorithm `json:"digest,omitempty,string"`
		KeyUsage             *string                 `json:"key_usage,omitempty"`
		ExtendedKeyUsage     *string                 `json:"extended_key_usage,omitempty"`
		Days                 int                     `json:"days,omitempty,string"`
		Key                  string                  `json:"-" gorm:"type:longtext"`
		Cert                 string                  `json:"cert,omitempty" gorm:"type:longtext"`
		IssuerKeyHash        string                  `json:"issuer_key_hash,omitempty" gorm:"UNIQUE_INDEX"`
		IssuerNameHash       string                  `json:"issuer_name_hash,omitempty" gorm:"UNIQUE_INDEX"`
		OCSPUrl              string                  `json:"ocsp_url,omitempty"`
		SCEPAssociateProfile string                  `gorm:"-"`
		Cloud                cloud.Cloud             `gorm:"-"`
		SerialNumber         int                     `json:"-"`
	}

	// Profile struct
	Profile struct {
		ID                    uint                    `gorm:"primarykey"`
		CreatedAt             time.Time               `json:"-"`
		UpdatedAt             time.Time               `json:"-"`
		DeletedAt             gorm.DeletedAt          `json:"-" gorm:"index"`
		DB                    *gorm.DB                `json:"-" gorm:"-"`
		Ctx                   context.Context         `json:"-" gorm:"-"`
		Name                  string                  `json:"name" gorm:"UNIQUE"`
		Mail                  string                  `json:"mail,omitempty" gorm:"INDEX:mail"`
		Organisation          string                  `json:"organisation,omitempty" gorm:"INDEX:organisation"`
		OrganisationalUnit    string                  `json:"organisational_unit,omitempty"`
		Country               string                  `json:"country,omitempty"`
		State                 string                  `json:"state,omitempty"`
		Locality              string                  `json:"locality,omitempty"`
		StreetAddress         string                  `json:"street_address,omitempty"`
		PostalCode            string                  `json:"postal_code,omitempty"`
		Ca                    CA                      `json:"-"`
		CaID                  uint                    `json:"ca_id,omitempty,string" gorm:"INDEX:ca_id"`
		CaName                string                  `json:"ca_name,omitempty" gorm:"INDEX:ca_name"`
		Validity              int                     `json:"validity,omitempty,string"`
		KeyType               *types.Type             `json:"key_type,omitempty,string"`
		KeySize               int                     `json:"key_size,omitempty,string"`
		Digest                x509.SignatureAlgorithm `json:"digest,omitempty,string"`
		KeyUsage              *string                 `json:"key_usage,omitempty"`
		ExtendedKeyUsage      *string                 `json:"extended_key_usage,omitempty"`
		OCSPUrl               string                  `json:"ocsp_url,omitempty"`
		P12MailPassword       int                     `json:"p12_mail_password,omitempty,string"`
		P12MailSubject        string                  `json:"p12_mail_subject,omitempty"`
		P12MailFrom           string                  `json:"p12_mail_from,omitempty"`
		P12MailHeader         string                  `json:"p12_mail_header,omitempty"`
		P12MailFooter         string                  `json:"p12_mail_footer,omitempty"`
		SCEPEnabled           int                     `json:"scep_enabled,omitempty"`
		SCEPChallengePassword string                  `json:"scep_challenge_password,omitempty"`
		SCEPDaysBeforeRenewal int                     `json:"scep_days_before_renewal,string" gorm:"default:14"`
		DaysBeforeRenewal     int                     `json:"days_before_renewal,string" gorm:"default:14"`
		RenewalMail           int                     `json:"renewal_mail,omitempty,string" gorm:"default:1"`
		DaysBeforeRenewalMail int                     `json:"days_before_renewal_mail,string" gorm:"default:14"`
		// RenewalMailDays is an optional comma-separated list of
		// thresholds (in days before expiry) at which a renewal email
		// should be sent — e.g. "14,7,1". When empty, the single
		// DaysBeforeRenewalMail value is used in legacy one-shot mode.
		RenewalMailDays       string                  `json:"renewal_mail_days,omitempty"`
		RenewalMailSubject    string                  `json:"renewal_mail_subject,omitempty" gorm:"default:Certificate expiration"`
		RenewalMailFrom       string                  `json:"renewal_mail_from,omitempty"`
		RenewalMailHeader     string                  `json:"renewal_mail_header,omitempty"`
		RenewalMailFooter     string                  `json:"renewal_mail_footer,omitempty"`
		RevokedValidUntil     int                     `json:"revoked_valid_until,omitempty,string" gorm:"default:14"`
		CloudEnabled          int                     `json:"cloud_enabled,omitempty"`
		CloudService          string                  `json:"cloud_service,omitempty"`
		ScepServerEnabled     int                     `json:"scep_server_enabled,omitempty" gorm:"default:0"`
		ScepServer            SCEPServer              `json:"-"`
		ScepServerID          uint                    `json:"scep_server_id,omitempty,string" gorm:"INDEX:scep_server_id"`
		AllowDuplicatedCN     int                     `json:"allow_duplicated_cn,omitempty" gorm:"default:0"`
		MaximumDuplicatedCN   int                     `json:"maximum_duplicated_cn,omitempty,string" gorm:"default:0"`
	}

	// Cert struct
	Cert struct {
		ID                 uint            `gorm:"primarykey"`
		CreatedAt          time.Time       `json:"-"`
		UpdatedAt          time.Time       `json:"-"`
		DeletedAt          gorm.DeletedAt  `json:"-" gorm:"index"`
		DB                 *gorm.DB        `json:"-" gorm:"-"`
		Ctx                context.Context `json:"-" gorm:"-"`
		Cn                 string          `json:"cn,omitempty" gorm:"uniqueIndex:cn_serial"`
		Mail               string          `json:"mail,omitempty" gorm:"INDEX:mail"`
		Ca                 CA              `json:"-"`
		CaID               uint            `json:"ca_id,omitempty" gorm:"INDEX:ca_id"`
		CaName             string          `json:"ca_name,omitempty" gorm:"INDEX:ca_name"`
		StreetAddress      string          `json:"street_address,omitempty"`
		Organisation       string          `json:"organisation,omitempty" gorm:"INDEX:organisation"`
		OrganisationalUnit string          `json:"organisational_unit,omitempty"`
		Country            string          `json:"country,omitempty"`
		State              string          `json:"state,omitempty"`
		Locality           string          `json:"locality,omitempty"`
		PostalCode         string          `json:"postal_code,omitempty"`
		Key                string          `json:"-" gorm:"type:longtext"`
		Cert               string          `json:"cert,omitempty" gorm:"type:longtext"`
		Profile            Profile         `json:"-"`
		ProfileID          uint            `json:"profile_id,omitempty,string" gorm:"INDEX:profile_id"`
		ProfileName        string          `json:"profile_name,omitempty" gorm:"INDEX:profile_name"`
		ValidUntil         time.Time       `json:"valid_until,omitempty" gorm:"index:valid_until;type:datetime"`
		NotBefore          time.Time       `json:"not_before,omitempty" gorm:"index:not_before;type:datetime"`
		Date               time.Time       `json:"date,omitempty" gorm:"default:CURRENT_TIMESTAMP"`
		SerialNumber       string          `json:"serial_number,omitempty" gorm:"uniqueIndex:cn_serial"`
		DNSNames           string          `json:"dns_names,omitempty"`
		IPAddresses        string          `json:"ip_addresses,omitempty"`
		Scep               *bool           `json:"scep,omitempty" gorm:"default:false"`
		Csr                *bool           `json:"csr,omitempty" gorm:"default:false"`
		Alert              *bool           `json:"alert,omitempty" gorm:"default:false"`
		// AlertedDays tracks which renewal-mail thresholds (from the
		// profile's RenewalMailDays list) have already triggered an
		// email for this cert; stored as comma-separated ints. Stays
		// empty in the legacy single-threshold path.
		AlertedDays        string          `json:"alerted_days,omitempty"`
		Subject            string          `json:"-"`
	}

	// CSR struct
	CSR struct {
		DB  *gorm.DB        `gorm:"-"`
		Ctx context.Context `gorm:"-"`
		Csr string          `json:"csr"`
	}

	// RevokedCert struct
	RevokedCert struct {
		ID                 uint            `gorm:"primarykey"`
		CreatedAt          time.Time       `json:"-"`
		UpdatedAt          time.Time       `json:"-"`
		DeletedAt          gorm.DeletedAt  `json:"-" gorm:"index"`
		DB                 *gorm.DB        `gorm:"-"`
		Ctx                context.Context `gorm:"-"`
		Cn                 string          `json:"cn,omitempty" gorm:"INDEX:cn"`
		Mail               string          `json:"mail,omitempty" gorm:"INDEX:mail"`
		Ca                 CA              `json:"-"`
		CaID               uint            `json:"ca_id,omitempty" gorm:"INDEX:ca_id"`
		CaName             string          `json:"ca_name,omitempty" gorm:"INDEX:ca_name"`
		StreetAddress      string          `json:"street_address,omitempty"`
		Organisation       string          `json:"organisation,omitempty" gorm:"INDEX:organisation"`
		OrganisationalUnit string          `json:"organisational_unit,omitempty"`
		Country            string          `json:"country,omitempty"`
		State              string          `json:"state,omitempty"`
		Locality           string          `json:"locality,omitempty"`
		PostalCode         string          `json:"postal_code,omitempty"`
		Key                string          `json:"-" gorm:"type:longtext"`
		Cert               string          `json:"cert,omitempty" gorm:"type:longtext"`
		Profile            Profile         `json:"-"`
		ProfileID          uint            `json:"profile_id,omitempty" gorm:"INDEX:profile_id"`
		ProfileName        string          `json:"profile_name,omitempty" gorm:"INDEX:profile_name"`
		ValidUntil         time.Time       `json:"valid_until,omitempty" gorm:"index:valid_until;type:datetime"`
		NotBefore          time.Time       `json:"not_before,omitempty" gorm:"index:not_before;type:datetime"`
		Date               time.Time       `json:"date,omitempty" gorm:"default:CURRENT_TIMESTAMP"`
		SerialNumber       string          `json:"serial_number,omitempty"`
		DNSNames           string          `json:"dns_names,omitempty"`
		IPAddresses        string          `json:"ip_addresses,omitempty"`
		Revoked            time.Time       `json:"revoked,omitempty" gorm:"INDEX:revoked"`
		CRLReason          int             `json:"crl_reason,omitempty" gorm:"INDEX:crl_reason"`
		Subject            string          `json:"-"`
	}
	// SCEP struct
	SCEPServer struct {
		ID           uint            `gorm:"primarykey"`
		CreatedAt    time.Time       `json:"-"`
		UpdatedAt    time.Time       `json:"-"`
		DeletedAt    gorm.DeletedAt  `json:"-" gorm:"index"`
		DB           *gorm.DB        `json:"-" gorm:"-"`
		Ctx          context.Context `json:"-" gorm:"-"`
		Name         string          `json:"name,omitempty" gorm:"UNIQUE"`
		URL          string          `json:"url,omitempty"`
		SharedSecret string          `json:"shared_secret,omitempty"`
	}
)

type Tabler interface {
	TableName() string
}

// TableName overrides the table name used by CA to `pki_cas`
func (CA) TableName() string {
	return "pki_cas"
}

// TableName overrides the table name used by Profiles to `pki_profiles`
func (Profile) TableName() string {
	return "pki_profiles"
}

// TableName overrides the table name used by Cert to `pki_certs`
func (Cert) TableName() string {
	return "pki_certs"
}

// TableName overrides the table name used by Cert to `pki_revoked_certs`
func (RevokedCert) TableName() string {
	return "pki_revoked_certs"
}

// TableName overrides the table name used by SCEPServer to `pki_scep`
func (SCEPServer) TableName() string {
	return "pki_scep_servers"
}

const dbError = "A database error occured. See log for details."

// Digest Values:
// 0 UnknownSignatureAlgorithm
// 1 MD2WithRSA
// 2 MD5WithRSA
// 3 SHA1WithRSA
// 4 SHA256WithRSA
// 5 SHA384WithRSA
// 6 SHA512WithRSA
// 7 DSAWithSHA1
// 8 DSAWithSHA256
// 9 ECDSAWithSHA1
// 10 ECDSAWithSHA256
// 11 ECDSAWithSHA384
// 12 ECDSAWithSHA512
// 13 SHA256WithRSAPSS
// 14 SHA384WithRSAPSS
// 15 SHA512WithRSAPSS
// 16 PureEd25519

// KeyUsage Values:
// 1 KeyUsageDigitalSignature
// 2 KeyUsageContentCommitment
// 4 KeyUsageKeyEncipherment
// 8 KeyUsageDataEncipherment
// 16 KeyUsageKeyAgreement
// 32 KeyUsageCertSign
// 64 KeyUsageCRLSign
// 128 KeyUsageEncipherOnly
// 256 KeyUsageDecipherOnly

// ExtendedKeyUsage Values:
// 0 ExtKeyUsageAny
// 1 ExtKeyUsageServerAuth
// 2 ExtKeyUsageClientAuth
// 3 ExtKeyUsageCodeSigning
// 4 ExtKeyUsageEmailProtection
// 5 ExtKeyUsageIPSECEndSystem
// 6 ExtKeyUsageIPSECTunnel
// 7 ExtKeyUsageIPSECUser
// 8 ExtKeyUsageTimeStamping
// 9 ExtKeyUsageOCSPSigning
// 10 ExtKeyUsageMicrosoftServerGatedCrypto
// 11 ExtKeyUsageNetscapeServerGatedCrypto
// 12 ExtKeyUsageMicrosoftCommercialCodeSigning
// 13 ExtKeyUsageMicrosoftKernelCodeSigning


func ProfileAttributes(prof Profile) map[string]string {
	var attributes map[string]string
	attributes = make(map[string]string)

	if len(prof.Organisation) > 0 {
		attributes["Organization"] = prof.Organisation
	}

	if len(prof.OrganisationalUnit) > 0 {
		attributes["OrganizationalUnit"] = prof.OrganisationalUnit
	}

	if len(prof.Country) > 0 {
		attributes["Country"] = prof.Country
	}

	if len(prof.State) > 0 {
		attributes["State"] = prof.State
	}

	if len(prof.Locality) > 0 {
		attributes["Locality"] = prof.Locality
	}

	if len(prof.StreetAddress) > 0 {
		attributes["StreetAddress"] = prof.StreetAddress
	}

	if len(prof.PostalCode) > 0 {
		attributes["PostalCode"] = prof.PostalCode
	}

	if len(*prof.ExtendedKeyUsage) > 0 {
		attributes["ExtendedKeyUsage"] = *prof.ExtendedKeyUsage
	}
	if len(*prof.KeyUsage) > 0 {
		attributes["KeyUsage"] = *prof.KeyUsage
	}

	if len(prof.OCSPUrl) > 0 {
		attributes["OCSPUrl"] = prof.OCSPUrl
	}

	if len(prof.Mail) > 0 {
		attributes["Mail"] = prof.Mail
	}
	if len(prof.Digest.String()) > 0 {
		val := strconv.Itoa(int(prof.Digest))
		attributes["Digest"] = val
	}
	return attributes
}

