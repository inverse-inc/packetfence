package models

import (
	"time"

	"bytes"
	"crypto/dsa"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha1"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/hex"
	"encoding/pem"
	"errors"
	"math/big"
	"strconv"
	"strings"

	"github.com/knq/pemutil"
	// Import MySQL lib

	"context"
	"fmt"
	"html/template"
	"io"
	"io/ioutil"

	"github.com/inverse-inc/packetfence/go/caddy/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/types"
	"github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/mysql"
	pkcs12 "software.sslmate.com/src/go-pkcs12"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"golang.org/x/text/language"
	"golang.org/x/text/message"
	"golang.org/x/text/message/catalog"
	gomail "gopkg.in/gomail.v2"
	yaml "gopkg.in/yaml.v2"
)

type (
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
		KeyType          *types.Type             `json:"key_type,omitempty,string"`
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
		KeyType          *types.Type             `json:"key_type,omitempty,string"`
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

func (c CA) New(pfpki *types.Handler) (types.Info, error) {

	Information := types.Info{}

	keyOut, pub, key, err := certutils.GenerateKey(*c.KeyType, c.KeySize)

	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	skid, err := certutils.CalculateSKID(pub)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	var cadb CA
	var newcadb []CA

	var SerialNumber *big.Int

	if CaDB := pfpki.DB.Last(&cadb); CaDB.Error != nil {
		SerialNumber = big.NewInt(1)
	} else {
		SerialNumber = big.NewInt(int64(cadb.ID + 1))
	}

	ca := &x509.Certificate{
		SerialNumber: SerialNumber,
		Subject: pkix.Name{
			Organization:  []string{c.Organisation},
			Country:       []string{c.Country},
			Province:      []string{c.State},
			Locality:      []string{c.Locality},
			StreetAddress: []string{c.StreetAddress},
			PostalCode:    []string{c.PostalCode},
			CommonName:    c.Cn,
		},
		NotBefore:             time.Now(),
		NotAfter:              time.Now().AddDate(0, 0, c.Days),
		IsCA:                  true,
		SignatureAlgorithm:    c.Digest,
		ExtKeyUsage:           certutils.Extkeyusage(strings.Split(*c.ExtendedKeyUsage, "|")),
		KeyUsage:              x509.KeyUsage(certutils.Keyusage(strings.Split(*c.KeyUsage, "|"))),
		BasicConstraintsValid: true,
		EmailAddresses:        []string{c.Mail},
		SubjectKeyId:          skid,
		AuthorityKeyId:        skid,
	}

	var caBytes []byte

	switch *c.KeyType {
	case certutils.KEY_RSA:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(*rsa.PrivateKey))
	case certutils.KEY_ECDSA:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(*ecdsa.PrivateKey))
	case certutils.KEY_DSA:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(*dsa.PrivateKey))
	}
	if err != nil {
		return Information, err
	}

	cert := new(bytes.Buffer)

	// Public key
	pem.Encode(cert, &pem.Block{Type: "CERTIFICATE", Bytes: caBytes})

	// Calculate the IssuerNameHash
	catls, err := tls.X509KeyPair([]byte(cert.String()), []byte(keyOut.String()))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	h := sha1.New()

	h.Write(cacert.RawIssuer)

	if err := pfpki.DB.Create(&CA{Cn: c.Cn, Mail: c.Mail, Organisation: c.Organisation, Country: c.Country, State: c.State, Locality: c.Locality, StreetAddress: c.StreetAddress, PostalCode: c.PostalCode, KeyType: c.KeyType, KeySize: c.KeySize, Digest: c.Digest, KeyUsage: c.KeyUsage, ExtendedKeyUsage: c.ExtendedKeyUsage, Days: c.Days, Key: keyOut.String(), Cert: cert.String(), IssuerKeyHash: hex.EncodeToString(skid), IssuerNameHash: hex.EncodeToString(h.Sum(nil))}).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}

	pfpki.DB.Select("id, cn, mail, organisation, country, state, locality, street_address, postal_code, key_type, key_size, digest, key_usage, extended_key_usage, days, cert").Where("cn = ?", c.Cn).First(&newcadb)
	Information.Entries = newcadb

	return Information, nil
}

func (c CA) GetByID(pfpki *types.Handler, params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var cadb []CA
	if val, ok := params["id"]; ok {
		allFields := strings.Join(sql.SqlFields(c)[:], ",")
		pfpki.DB.Select(allFields).Where("`id` = ?", val).First(&cadb)
	}
	Information.Entries = cadb

	return Information, nil
}

func (c CA) Fix(pfpki *types.Handler) (types.Info, error) {
	Information := types.Info{}
	var cadb []CA

	pfpki.DB.Find(&cadb)
	for _, v := range cadb {
		if v.IssuerNameHash == "" {

			// Calculate the IssuerNameHash
			catls, err := tls.X509KeyPair([]byte(v.Cert), []byte(v.Key))
			if err != nil {
				Information.Error = err.Error()
				return Information, err
			}
			cacert, err := x509.ParseCertificate(catls.Certificate[0])
			if err != nil {
				Information.Error = err.Error()
				return Information, err
			}
			h := sha1.New()

			h.Write(cacert.RawIssuer)
			// var store pemutil.Store
			store := make(map[pemutil.BlockType]interface{})

			pemutil.Decode(store, []byte(v.Cert))
			var skid []byte
			for _, pemUtil := range store {
				cert := pemUtil.(*x509.Certificate)
				skid, _ = certutils.CalculateSKID(cert.PublicKey)
			}

			v.IssuerKeyHash = hex.EncodeToString(skid)
			v.IssuerNameHash = hex.EncodeToString(h.Sum(nil))
			pfpki.DB.Save(&v)
		}
	}

	return Information, nil
}

func (c CA) Paginated(pfpki *types.Handler, vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	var count int
	pfpki.DB.Model(&CA{}).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		sql, err := vars.Sql(c)
		if err != nil {
			Information.Error = err.Error()
			return Information, errors.New("A database error occured. See log for details.")
		}
		var cadb []CA
		pfpki.DB.Select(sql.Select).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&cadb)
		Information.Entries = cadb
	}

	return Information, nil
}

func (c CA) Search(pfpki *types.Handler, vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	sql, err := vars.Sql(c)
	if err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}
	var count int
	pfpki.DB.Model(&CA{}).Where(sql.Where.Query, sql.Where.Values...).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		var cadb []CA
		pfpki.DB.Select(sql.Select).Where(sql.Where.Query, sql.Where.Values...).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&cadb)
		Information.Entries = cadb
	}

	return Information, nil
}

func (p Profile) New(pfpki *types.Handler) (types.Info, error) {

	var profiledb []Profile
	var err error
	Information := types.Info{}
	switch *p.KeyType {
	case certutils.KEY_RSA:
		if p.KeySize < 2048 {
			err = errors.New("invalid private key size, should be at least 2048")
			Information.Error = err.Error()
			return Information, err
		}
	case certutils.KEY_ECDSA:
		if !(p.KeySize == 256 || p.KeySize == 384 || p.KeySize == 521) {
			err = errors.New("invalid private key size, should be 256 or 384 or 521")
			Information.Error = err.Error()
			return Information, err
		}
	case certutils.KEY_DSA:
		if !(p.KeySize == 1024 || p.KeySize == 2048 || p.KeySize == 3072) {
			err = errors.New("invalid private key size, should be 1024 or 2048 or 3072")
			Information.Error = err.Error()
			return Information, err
		}
	default:
		return Information, errors.New("KeyType unsupported")

	}

	var ca CA
	if CaDB := pfpki.DB.First(&ca, p.CaID).Find(&ca); CaDB.Error != nil {
		Information.Error = CaDB.Error.Error()
		return Information, CaDB.Error
	}

	if err := pfpki.DB.Create(&Profile{Name: p.Name, Ca: ca, CaID: p.CaID, CaName: ca.Cn, Validity: p.Validity, KeyType: p.KeyType, KeySize: p.KeySize, Digest: p.Digest, KeyUsage: p.KeyUsage, ExtendedKeyUsage: p.ExtendedKeyUsage, P12MailPassword: p.P12MailPassword, P12MailSubject: p.P12MailSubject, P12MailFrom: p.P12MailFrom, P12MailHeader: p.P12MailHeader, P12MailFooter: p.P12MailFooter}).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}
	pfpki.DB.Select("id, name, ca_id, ca_name, validity, key_type, key_size, digest, key_usage, extended_key_usage, p12_mail_password, p12_mail_subject, p12_mail_from, p12_mail_header, p12_mail_footer").Where("name = ?", p.Name).First(&profiledb)
	Information.Entries = profiledb

	return Information, nil
}

func (p Profile) Update(pfpki *types.Handler) (types.Info, error) {
	var profiledb []Profile
	Information := types.Info{}
	if err := pfpki.DB.Model(&Profile{}).Updates(&Profile{P12MailPassword: p.P12MailPassword, P12MailSubject: p.P12MailSubject, P12MailFrom: p.P12MailFrom, P12MailHeader: p.P12MailHeader, P12MailFooter: p.P12MailFooter}).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}
	pfpki.DB.Select("id, name, ca_id, ca_name, validity, key_type, key_size, digest, key_usage, extended_key_usage, p12_mail_password, p12_mail_subject, p12_mail_from, p12_mail_header, p12_mail_footer").Where("name = ?", p.Name).First(&profiledb)
	Information.Entries = profiledb

	return Information, nil
}

func (p Profile) GetByID(pfpki *types.Handler, params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var profiledb []Profile
	if val, ok := params["id"]; ok {
		allFields := strings.Join(sql.SqlFields(p)[:], ",")
		pfpki.DB.Select(allFields).Where("`id` = ?", val).First(&profiledb)
	}
	Information.Entries = profiledb

	return Information, nil
}

func (p Profile) Paginated(pfpki *types.Handler, vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	var count int
	pfpki.DB.Model(&Profile{}).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		sql, err := vars.Sql(p)
		if err != nil {
			Information.Error = err.Error()
			return Information, errors.New("A database error occured. See log for details.")
		}
		var profiledb []Profile
		pfpki.DB.Select(sql.Select).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&profiledb)
		Information.Entries = profiledb
	}

	return Information, nil
}

func (p Profile) Search(pfpki *types.Handler, vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	sql, err := vars.Sql(p)
	if err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}
	var count int
	pfpki.DB.Model(&Profile{}).Where(sql.Where.Query, sql.Where.Values...).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		var profiledb []Profile
		pfpki.DB.Select(sql.Select).Where(sql.Where.Query, sql.Where.Values...).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&profiledb)
		Information.Entries = profiledb
	}

	return Information, nil
}

func (c Cert) New(pfpki *types.Handler) (types.Info, error) {
	Information := types.Info{}

	// Find the profile
	var prof Profile
	if profDB := pfpki.DB.First(&prof, c.ProfileID); profDB.Error != nil {
		Information.Error = profDB.Error.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}

	// Find the CA
	var ca CA
	if CaDB := pfpki.DB.First(&ca, prof.CaID).Find(&ca); CaDB.Error != nil {
		Information.Error = CaDB.Error.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}
	// Load the certificates from the database
	catls, err := tls.X509KeyPair([]byte(ca.Cert), []byte(ca.Key))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	var certdb Cert
	var newcertdb []Cert
	var SerialNumber *big.Int

	if CertDB := pfpki.DB.Last(&certdb).Related(&ca); CertDB.Error != nil {
		SerialNumber = big.NewInt(1)
	} else {
		SerialNumber = big.NewInt(int64(certdb.ID + 1))
	}

	keyOut, pub, _, err := certutils.GenerateKey(*prof.KeyType, prof.KeySize)

	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	skid, err := certutils.CalculateSKID(pub)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	// Prepare certificate
	cert := &x509.Certificate{
		SerialNumber: SerialNumber,
		Subject: pkix.Name{
			Organization:  []string{c.Organisation},
			Country:       []string{c.Country},
			Province:      []string{c.State},
			Locality:      []string{c.Locality},
			StreetAddress: []string{c.StreetAddress},
			PostalCode:    []string{c.PostalCode},
			CommonName:    c.Cn,
		},
		NotBefore:      time.Now(),
		NotAfter:       time.Now().AddDate(0, 0, prof.Validity),
		ExtKeyUsage:    certutils.Extkeyusage(strings.Split(*prof.ExtendedKeyUsage, "|")),
		KeyUsage:       x509.KeyUsage(certutils.Keyusage(strings.Split(*prof.KeyUsage, "|"))),
		EmailAddresses: []string{c.Mail},
		SubjectKeyId:   skid,
	}

	// Sign the certificate
	certByte, err := x509.CreateCertificate(rand.Reader, cert, cacert, pub, catls.PrivateKey)

	certBuff := new(bytes.Buffer)

	// Public key
	pem.Encode(certBuff, &pem.Block{Type: "CERTIFICATE", Bytes: certByte})

	if err := pfpki.DB.Create(&Cert{Cn: c.Cn, Ca: ca, CaName: ca.Cn, ProfileName: prof.Name, SerialNumber: SerialNumber.String(), Mail: c.Mail, StreetAddress: c.StreetAddress, Organisation: c.Organisation, Country: c.Country, State: c.State, Locality: c.Locality, PostalCode: c.PostalCode, Profile: prof, Key: keyOut.String(), Cert: certBuff.String(), ValidUntil: cert.NotAfter}).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}
	pfpki.DB.Select("id, cn, mail, street_address, organisation, country, state, locality, postal_code, cert, profile_id, profile_name, ca_name, ca_id, valid_until, serial_number").Where("cn = ?", c.Cn).First(&newcertdb)
	Information.Entries = newcertdb

	return Information, nil
}

func (c Cert) GetByID(pfpki *types.Handler, params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var certdb []Cert
	allFields := strings.Join(sql.SqlFields(c)[:], ",")
	if val, ok := params["id"]; ok {
		pfpki.DB.Select(allFields).Where("`id` = ?", val).First(&certdb)
	}
	if val, ok := params["cn"]; ok {
		pfpki.DB.Select(allFields).Where("`cn` = ?", val).First(&certdb)
	}

	Information.Entries = certdb

	return Information, nil
}

func (c Cert) Paginated(pfpki *types.Handler, vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	var count int
	pfpki.DB.Model(&Cert{}).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		sql, err := vars.Sql(c)
		if err != nil {
			Information.Error = err.Error()
			return Information, errors.New("A database error occured. See log for details.")
		}
		var certdb []Cert
		pfpki.DB.Select(sql.Select).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&certdb)
		Information.Entries = certdb
	}

	return Information, nil
}

func (c Cert) Search(pfpki *types.Handler, vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	sql, err := vars.Sql(c)
	if err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}
	var count int
	pfpki.DB.Model(&Cert{}).Where(sql.Where.Query, sql.Where.Values...).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		var certdb []Cert
		pfpki.DB.Select(sql.Select).Where(sql.Where.Query, sql.Where.Values...).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&certdb)
		Information.Entries = certdb
	}

	return Information, nil
}

func (c Cert) Download(pfpki *types.Handler, params map[string]string) (types.Info, error) {
	Information := types.Info{}
	// Find the Cert
	var cert Cert
	if val, ok := params["cn"]; ok {
		if CertDB := pfpki.DB.Where("Cn = ?", val).Find(&cert); CertDB.Error != nil {
			Information.Error = CertDB.Error.Error()
			return Information, errors.New("A database error occured. See log for details.")
		}
	}
	if val, ok := params["id"]; ok {
		if CertDB := pfpki.DB.First(&cert, val); CertDB.Error != nil {
			Information.Error = CertDB.Error.Error()
			return Information, errors.New("A database error occured. See log for details.")
		}
	}

	// Find the CA
	var ca CA
	if CaDB := pfpki.DB.Model(&cert).Related(&ca); CaDB.Error != nil {
		Information.Error = CaDB.Error.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}

	// Load the certificates from the database
	certtls, err := tls.X509KeyPair([]byte(cert.Cert), []byte(cert.Key))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	// Find the profile
	var prof Profile
	if profDB := pfpki.DB.Where("Name = ?", cert.ProfileName).Find(&prof); profDB.Error != nil {
		Information.Error = profDB.Error.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}

	certificate, err := x509.ParseCertificate(certtls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	// Load the certificates from the database
	catls, err := tls.X509KeyPair([]byte(ca.Cert), []byte(ca.Key))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	var CaCert []*x509.Certificate

	CaCert = append(CaCert, cacert)

	var password string
	if val, ok := params["password"]; ok {
		password = val
	} else {
		password = certutils.GeneratePassword()
	}
	Information.Password = password

	pkcs12, err := pkcs12.Encode(certutils.PRNG, certtls.PrivateKey, certificate, CaCert, password)

	if _, ok := params["password"]; ok {
		Information.Raw = pkcs12
		Information.ContentType = "application/x-pkcs12"
	} else {
		Information, err = email(pfpki.Ctx, cert, prof, pkcs12, password)
	}

	return Information, err
}

func (c Cert) Revoke(pfpki *types.Handler, params map[string]string) (types.Info, error) {

	Information := types.Info{}
	// Find the Cert
	var cert Cert

	id := params["id"]
	reason := params["reason"]

	if CertDB := pfpki.DB.Where("id = ?", id).Find(&cert); CertDB.Error != nil {
		Information.Error = CertDB.Error.Error()
		return Information, CertDB.Error
	}

	// Find the CA
	var ca CA
	if CaDB := pfpki.DB.Model(&cert).Related(&ca); CaDB.Error != nil {
		Information.Error = CaDB.Error.Error()
		return Information, CaDB.Error
	}

	// Find the Profile
	var profile Profile
	if ProfileDB := pfpki.DB.Model(&cert).Related(&profile); ProfileDB.Error != nil {
		Information.Error = ProfileDB.Error.Error()
		return Information, ProfileDB.Error
	}

	intreason, err := strconv.Atoi(reason)
	if err != nil {
		Information.Error = "Reason unsupported"
		return Information, errors.New("Reason unsupported")
	}

	if err := pfpki.DB.Create(&RevokedCert{Cn: cert.Cn, Mail: cert.Mail, Ca: ca, CaID: cert.CaID, CaName: cert.CaName, StreetAddress: cert.StreetAddress, Organisation: cert.Organisation, Country: cert.Country, State: cert.State, Locality: cert.Locality, PostalCode: cert.Locality, Key: cert.Key, Cert: cert.Cert, Profile: profile, ProfileID: cert.ProfileID, ProfileName: cert.ProfileName, ValidUntil: cert.ValidUntil, Date: cert.Date, Revoked: time.Now(), CRLReason: intreason, SerialNumber: cert.SerialNumber}).Error; err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	if err := pfpki.DB.Unscoped().Delete(&cert).Error; err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	return Information, nil
}

func (c RevokedCert) GetByID(pfpki *types.Handler, params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var revokedcertdb []RevokedCert
	if val, ok := params["id"]; ok {
		allFields := strings.Join(sql.SqlFields(c)[:], ",")
		pfpki.DB.Select(allFields).Where("`id` = ?", val).First(&revokedcertdb)
	}
	Information.Entries = revokedcertdb

	return Information, nil
}

func (c RevokedCert) Paginated(pfpki *types.Handler, vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	var count int
	pfpki.DB.Model(&Cert{}).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		sql, err := vars.Sql(c)
		if err != nil {
			Information.Error = err.Error()
			return Information, err
		}
		var revokedcertdb []RevokedCert
		pfpki.DB.Select(sql.Select).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&revokedcertdb)
		Information.Entries = revokedcertdb
	}

	return Information, nil
}

func (c RevokedCert) Search(pfpki *types.Handler, vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	sql, err := vars.Sql(c)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	var count int
	pfpki.DB.Model(&Cert{}).Where(sql.Where.Query, sql.Where.Values...).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		var revokedcertdb []RevokedCert
		pfpki.DB.Select(sql.Select).Where(sql.Where.Query, sql.Where.Values...).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&revokedcertdb)
		Information.Entries = revokedcertdb
	}

	return Information, nil
}

// EmailType strucure
type EmailType struct {
	Header   string
	Footer   string
	Password string
}

func email(ctx context.Context, cert Cert, profile Profile, file []byte, password string) (types.Info, error) {
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Alerting)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Advanced)
	alerting := pfconfigdriver.Config.PfConf.Alerting
	advanced := pfconfigdriver.Config.PfConf.Advanced

	Information := types.Info{}

	dict, err := parseYAMLDict()
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	cat, err := catalog.NewFromMap(dict)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	message.DefaultCatalog = cat

	m := gomail.NewMessage()
	m.SetHeader("From", alerting.FromAddr)
	m.SetHeader("To", cert.Mail)
	m.SetHeader("Subject", profile.P12MailSubject)

	email := EmailType{Header: profile.P12MailHeader, Footer: profile.P12MailFooter}

	// Undefined Header
	if profile.P12MailHeader == "" {
		email.Header = "msg_header"
	}
	// Undefined Footer
	if profile.P12MailHeader == "" {
		email.Footer = "msg_footer"
	}

	if profile.P12MailPassword == 1 {
		email.Password = password
		Information.Password = password
	}

	lang := language.MustParse(advanced.Language)

	emailContent, err := parseTemplate("emails-pki_certificate.html", lang, email)

	m.SetBody("text/html", emailContent)

	m.Attach(cert.Cn+".p12", gomail.SetCopyFunc(func(w io.Writer) error {
		_, err := w.Write(file)
		return err
	}))

	d := gomail.NewDialer(alerting.SMTPServer, alerting.SMTPPort, alerting.SMTPUsername, alerting.SMTPPassword)

	if alerting.SMTPVerifySSL == "disabled" {
		d.TLSConfig = &tls.Config{InsecureSkipVerify: true}
	}

	if err := d.DialAndSend(m); err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	return Information, nil
}

func parseTemplate(tplName string, lang language.Tag, data interface{}) (string, error) {
	p := message.NewPrinter(lang)
	fmap := template.FuncMap{
		"translate": p.Sprintf,
	}

	t, err := template.New(tplName).Funcs(fmap).ParseFiles("/usr/local/pf/html/captive-portal/templates/emails/" + tplName)
	if err != nil {
		return "", fmt.Errorf("cannot parse template")
	}

	buf := bytes.NewBuffer([]byte{})
	if err := t.Execute(buf, data); err != nil {
		return "", fmt.Errorf("cannot execute parse template")
	}

	return buf.String(), nil
}

func parseYAMLDict() (map[string]catalog.Dictionary, error) {
	dir := "/usr/local/pf/conf/caddy-services/locales"
	files, err := ioutil.ReadDir(dir)
	if err != nil {
		fmt.Println(err)
		return nil, err
	}

	translations := map[string]catalog.Dictionary{}

	for _, f := range files {
		yamlFile, err := ioutil.ReadFile(dir + "/" + f.Name())
		if err != nil {
			return nil, err
		}
		data := map[string]string{}
		err = yaml.Unmarshal(yamlFile, &data)
		if err != nil {
			return nil, err
		}

		lang := strings.Split(f.Name(), ".")[0]

		translations[lang] = &dictionary{Data: data}
	}

	return translations, nil
}

type dictionary struct {
	Data map[string]string
}

func (d *dictionary) Lookup(key string) (data string, ok bool) {
	if _, ok := d.Data[key]; !ok {
		return "", false
	}

	return "\x02" + d.Data[key], true
}
