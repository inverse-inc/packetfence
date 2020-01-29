package pfpki

import (
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
	"time"

	"github.com/jinzhu/gorm"

	// Import MySQL lib
	_ "github.com/jinzhu/gorm/dialects/mysql"
	pkcs12 "software.sslmate.com/src/go-pkcs12"
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

// CA struct
type CA struct {
	gorm.Model
	Cn               string                  `json:"cn" gorm:"UNIQUE"`
	Mail             string                  `json:"mail"`
	Organisation     string                  `json:"organisation"`
	Country          string                  `json:"country"`
	State            string                  `json:"state"`
	Locality         string                  `json:"locality"`
	StreetAddress    string                  `json:"street_address"`
	PostalCode       string                  `json:"postal_code"`
	KeyType          Type                    `json:"key_type,string"`
	KeySize          int                     `json:"key_size,string"`
	Digest           x509.SignatureAlgorithm `json:"digest,string"`
	KeyUsage         string                  `json:"key_usage,omitempty"`
	ExtendedKeyUsage string                  `json:"extended_key_usage,omitempty"`
	Days             int                     `json:"days,string"`
	Key              string                  `json:"key,omitempty" gorm:"type:longtext"`
	Cert             string                  `json:"cert,omitempty" gorm:"type:longtext"`
	IssuerKeyHash    string                  `json:"issuer_key_hash,omitempty" gorm:"UNIQUE_INDEX"`
	IssuerNameHash   string                  `json:"issuer_name_hash,omitempty" gorm:"UNIQUE_INDEX"`
}

// Profile struct
type Profile struct {
	gorm.Model
	Name             string                  `json:"name" gorm:"UNIQUE"`
	Ca               CA                      `json:"ca"`
	CaID             uint                    `json:"ca_id,string"`
	CaName           string                  `json:"ca_name"`
	Validity         int                     `json:"validity,string"`
	KeyType          Type                    `json:"key_type,string"`
	KeySize          int                     `json:"key_size,string"`
	Digest           x509.SignatureAlgorithm `json:"digest,string"`
	KeyUsage         string                  `json:"key_usage,omitempty"`
	ExtendedKeyUsage string                  `json:"extended_key_usage,omitempty"`
	P12SmtpServer    string                  `json:"p12_smtp_server"`
	P12MailPassword  int                     `json:"p12_mail_password,string"`
	P12MailSubject   string                  `json:"p12_mail_subject"`
	P12MailFrom      string                  `json:"p12_mail_from"`
	P12MailHeader    string                  `json:"p12_mail_header"`
	P12MailFooter    string                  `json:"p12_mail_footer"`
}

// Cert struct
type Cert struct {
	gorm.Model
	Cn            string  `json:"cn"  gorm:"UNIQUE"`
	Mail          string  `json:"mail"`
	Ca            CA      `json:"ca"`
	CaID          uint    `json:"ca_id,string"`
	CaName        string  `json:"ca_name"`
	StreetAddress string  `json:"street_address,omitempty"`
	Organisation  string  `json:"organisation,omitempty"`
	Country       string  `json:"country,omitempty"`
	State         string  `json:"state,omitempty"`
	Locality      string  `json:"locality,omitempty"`
	PostalCode    string  `json:"postal_code,omitempty"`
	Key           string  `json:"key,omitempty" gorm:"type:longtext"`
	Cert          string  `json:"publickey,omitempty" gorm:"type:longtext"`
	Profile       Profile `json:"profile,omitempty"`
	ProfileID     uint    `json:"profile_id,string"`
	ProfileName   string  `json:"profile_name,omitempty"`
	ValidUntil    time.Time
	Date          time.Time `gorm:"default:CURRENT_TIMESTAMP"`
	SerialNumber  string
}

// RevokedCert struct
type RevokedCert struct {
	gorm.Model
	Cn            string  `json:"cn""`
	Mail          string  `json:"mail"`
	Ca            CA      `json:"ca"`
	CaID          uint    `json:"caid,string"`
	StreetAddress string  `json:"street_address,omitempty"`
	Organisation  string  `json:"organisation,omitempty"`
	Country       string  `json:"country,omitempty"`
	State         string  `json:"state,omitempty"`
	Locality      string  `json:"locality,omitempty"`
	PostalCode    string  `json:"postal_code,omitempty"`
	Key           string  `json:"key,omitempty" gorm:"type:longtext"`
	Cert          string  `json:"publickey,omitempty" gorm:"type:longtext"`
	Profile       Profile `json:"profile,omitempty"`
	ProfileID     uint    `json:"profile_id,string"`
	ProfileName   string  `json:"profile_name,omitempty"`
	ValidUntil    time.Time
	Date          time.Time `gorm:"default:CURRENT_TIMESTAMP"`
	Revoked       time.Time
	CRLReason     int
	SerialNumber  string
}

func (c CA) new(pfpki *Handler) (Info, error) {
	// Create the table on the fly.
	pfpki.DB.AutoMigrate(&CA{})

	Information := Info{}

	keyOut, pub, key, err := GenerateKey(c.KeyType, c.KeySize)

	if err != nil {
		return Information, err
	}

	skid, err := calculateSKID(pub)
	if err != nil {
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
		ExtKeyUsage:           extkeyusage(strings.Split(c.ExtendedKeyUsage, "|")),
		KeyUsage:              x509.KeyUsage(keyusage(strings.Split(c.KeyUsage, "|"))),
		BasicConstraintsValid: true,
		EmailAddresses:        []string{c.Mail},
		SubjectKeyId:          skid,
		AuthorityKeyId:        skid,
	}

	var caBytes []byte

	switch c.KeyType {
	case KEY_RSA:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(*rsa.PrivateKey))
	case KEY_ECDSA:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(*ecdsa.PrivateKey))
	case KEY_DSA:
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
		return Information, err
	}
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		return Information, err
	}
	h := sha1.New()

	h.Write(cacert.RawIssuer)

	pfpki.DB.AutoMigrate(&CA{})

	if err := pfpki.DB.Create(&CA{Cn: c.Cn, Mail: c.Mail, Organisation: c.Organisation, Country: c.Country, State: c.State, Locality: c.Locality, StreetAddress: c.StreetAddress, PostalCode: c.PostalCode, KeyType: c.KeyType, KeySize: c.KeySize, Digest: c.Digest, KeyUsage: c.KeyUsage, ExtendedKeyUsage: c.ExtendedKeyUsage, Days: c.Days, Key: keyOut.String(), Cert: cert.String(), IssuerKeyHash: hex.EncodeToString(skid), IssuerNameHash: hex.EncodeToString(h.Sum(nil))}).Error; err != nil {
		return Information, err
	}

	pfpki.DB.Select("id, cn, mail, organisation, country, state, locality, street_address, postal_code, key_type, key_size, digest, key_usage, extended_key_usage, days, cert").Where("cn = ?", c.Cn).First(&newcadb)
	Information.Entries = newcadb
	return Information, nil
}

func (c CA) get(pfpki *Handler, params map[string]string) (Info, error) {
	Information := Info{}
	var cadb []CA
	if val, ok := params["id"]; ok {
		pfpki.DB.Select("id, cn, mail, organisation, country, state, locality, street_address, postal_code, key_type, key_size, digest, key_usage, extended_key_usage, days, cert").Where("id = ?", val).First(&cadb)
	} else {
		pfpki.DB.Select("id, cn, mail, organisation").Find(&cadb)
	}
	Information.Entries = cadb

	return Information, nil
}

// func (c *CA) save() {
// 	// Public key
// 	certOut, err := os.Create("ca.crt")
// 	pem.Encode(certOut, &pem.Block{Type: "CERTIFICATE", Bytes: ca_b})
// 	certOut.Close()

// 	// Private key
// 	keyOut, err := os.OpenFile("ca.key", os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
// 	pem.Encode(keyOut, &pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(priv)})
// 	keyOut.Close()

// }

func (p Profile) new(pfpki *Handler) (Info, error) {
	// Create the table on the fly.
	pfpki.DB.AutoMigrate(&Profile{})
	var profiledb []Profile

	Information := Info{}
	switch p.KeyType {
	case KEY_RSA:
		if p.KeySize < 2048 {
			return Information, errors.New("invalid private key size, should be at least 2048")
		}
	case KEY_ECDSA:
		if !(p.KeySize == 256 || p.KeySize == 384 || p.KeySize == 521) {
			return Information, errors.New("invalid private key size, should be 256 or 384 or 521")
		}
	case KEY_DSA:
		if !(p.KeySize == 1024 || p.KeySize == 2048 || p.KeySize == 3072) {
			return Information, errors.New("invalid private key size, should be 1024 or 2048 or 3072")
		}
	default:
		return Information, errors.New("KeyType unsupported")

	}

	var ca CA
	if CaDB := pfpki.DB.First(&ca, p.CaID).Find(&ca); CaDB.Error != nil {
		return Information, CaDB.Error
	}

	if err := pfpki.DB.Create(&Profile{Name: p.Name, Ca: ca, CaID: p.CaID, CaName: ca.Cn, Validity: p.Validity, KeyType: p.KeyType, KeySize: p.KeySize, Digest: p.Digest, KeyUsage: p.KeyUsage, ExtendedKeyUsage: p.ExtendedKeyUsage, P12SmtpServer: p.P12SmtpServer, P12MailPassword: p.P12MailPassword, P12MailSubject: p.P12MailSubject, P12MailFrom: p.P12MailFrom, P12MailHeader: p.P12MailHeader, P12MailFooter: p.P12MailFooter}).Error; err != nil {
		return Information, err
	}
	pfpki.DB.Select("id, name, ca_id, ca_name, validity, key_type, key_size, digest, key_usage, extended_key_usage, p12_smtp_server, p12_mail_password, p12_mail_subject, p12_mail_from, p12_mail_header, p12_mail_footer").Where("name = ?", p.Name).First(&profiledb)
	Information.Entries = profiledb
	return Information, nil
}

func (p Profile) get(pfpki *Handler, params map[string]string) (Info, error) {
	Information := Info{}
	var profiledb []Profile
	if val, ok := params["id"]; ok {
		pfpki.DB.Select("id, name, ca_id, ca_name, validity, key_type, key_size, digest, key_usage, extended_key_usage, p12_smtp_server, p12_mail_password, p12_mail_subject, p12_mail_from, p12_mail_header, p12_mail_footer").Where("id = ?", val).First(&profiledb)
	} else {
		pfpki.DB.Select("id, name, ca_id, ca_name").Find(&profiledb)
	}
	Information.Entries = profiledb

	return Information, nil
}

func (c Cert) new(pfpki *Handler) (Info, error) {
	Information := Info{}
	pfpki.DB.AutoMigrate(&Cert{})
	pfpki.DB.AutoMigrate(&RevokedCert{})

	// Find the profile
	var prof Profile
	if profDB := pfpki.DB.First(&prof, c.ProfileID); profDB.Error != nil {
		return Information, profDB.Error
	}

	// Find the CA
	var ca CA
	if CaDB := pfpki.DB.First(&ca, prof.CaID).Find(&ca); CaDB.Error != nil {
		return Information, CaDB.Error
	}
	// Load the certificates from the database
	catls, err := tls.X509KeyPair([]byte(ca.Cert), []byte(ca.Key))
	if err != nil {
		return Information, err
	}
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
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

	keyOut, pub, _, err := GenerateKey(prof.KeyType, prof.KeySize)

	if err != nil {
		return Information, err
	}

	skid, err := calculateSKID(pub)
	if err != nil {
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
		ExtKeyUsage:    extkeyusage(strings.Split(prof.ExtendedKeyUsage, "|")),
		KeyUsage:       x509.KeyUsage(keyusage(strings.Split(prof.KeyUsage, "|"))),
		EmailAddresses: []string{c.Mail},
		SubjectKeyId:   skid,
	}

	// Sign the certificate
	certByte, err := x509.CreateCertificate(rand.Reader, cert, cacert, pub, catls.PrivateKey)

	certBuff := new(bytes.Buffer)

	// Public key
	pem.Encode(certBuff, &pem.Block{Type: "CERTIFICATE", Bytes: certByte})

	if err := pfpki.DB.Create(&Cert{Cn: c.Cn, Ca: ca, CaName: ca.Cn, ProfileName: prof.Name, SerialNumber: SerialNumber.String(), Mail: c.Mail, StreetAddress: c.StreetAddress, Organisation: c.Organisation, Country: c.Country, State: c.State, Locality: c.Locality, PostalCode: c.PostalCode, Profile: prof, Key: keyOut.String(), Cert: certBuff.String(), ValidUntil: cert.NotAfter}).Error; err != nil {
		return Information, err
	}
	pfpki.DB.Select("id, cn, mail, street_address, organisation, country, state, locality, postal_code, cert, profile_id, profile_name, ca_name, ca_id, valid_until, serial_number").Where("cn = ?", c.Cn).First(&newcertdb)
	Information.Entries = newcertdb
	return Information, nil
}

func (c Cert) get(pfpki *Handler, params map[string]string) (Info, error) {
	Information := Info{}
	var certdb []Cert
	if val, ok := params["cn"]; ok {
		pfpki.DB.Select("id, cn, mail, street_address, organisation, country, state, locality, postal_code, cert, profile_id, profile_name, ca_name, ca_id, valid_until, serial_number").Where("cn = ?", val).First(&certdb)
	} else if val, ok := params["id"]; ok {
		pfpki.DB.Select("id, cn, mail, street_address, organisation, country, state, locality, postal_code, cert, profile_id, profile_name, ca_name, ca_id, valid_until, serial_number").First(&certdb, val)
	} else {
		pfpki.DB.Select("id, cn, mail, profile_id, profile_name, ca_name, ca_id").Find(&certdb)
	}
	Information.Entries = certdb

	return Information, nil
}

func (c Cert) download(pfpki *Handler, params map[string]string) (Info, error) {
	Information := Info{}
	// Find the Cert
	var cert Cert
	if val, ok := params["cn"]; ok {
		if CertDB := pfpki.DB.Where("Cn = ?", val).Find(&cert); CertDB.Error != nil {
			return Information, CertDB.Error
		}
	}
	if val, ok := params["id"]; ok {
		if CertDB := pfpki.DB.First(&cert, val); CertDB.Error != nil {
			return Information, CertDB.Error
		}
	}

	// Find the CA
	var ca CA
	if CaDB := pfpki.DB.Model(&cert).Related(&ca); CaDB.Error != nil {
		return Information, CaDB.Error
	}

	// Load the certificates from the database
	certtls, err := tls.X509KeyPair([]byte(cert.Cert), []byte(cert.Key))
	if err != nil {
		return Information, err
	}

	// Find the profile
	var prof Profile
	if profDB := pfpki.DB.Where("Name = ?", cert.ProfileName).Find(&prof); profDB.Error != nil {
		return Information, profDB.Error
	}

	certificate, err := x509.ParseCertificate(certtls.Certificate[0])
	if err != nil {
		return Information, err
	}

	// Load the certificates from the database
	catls, err := tls.X509KeyPair([]byte(ca.Cert), []byte(ca.Key))
	if err != nil {
		return Information, err
	}
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		return Information, err
	}

	var CaCert []*x509.Certificate

	CaCert = append(CaCert, cacert)

	var password string
	if val, ok := params["password"]; ok {
		password = val
	} else {
		password = generatePassword()
	}
	Information.Password = password

	pkcs12, err := pkcs12.Encode(PRNG, certtls.PrivateKey, certificate, CaCert, password)

	if _, ok := params["password"]; ok {
		Information.Raw = pkcs12
		Information.ContentType = "application/x-pkcs12"
	} else {
		Information, err = email(cert, prof, pkcs12, password)
	}

	return Information, err
}

func (c Cert) revoke(pfpki *Handler, params map[string]string) (Info, error) {

	pfpki.DB.AutoMigrate(&RevokedCert{})
	Information := Info{}
	// Find the Cert
	var cert Cert

	cn := params["cn"]
	reason := params["reason"]

	if CertDB := pfpki.DB.Where("Cn = ?", cn).Find(&cert); CertDB.Error != nil {
		return Information, CertDB.Error
	}

	// Find the CA
	var ca CA
	if CaDB := pfpki.DB.Model(&cert).Related(&ca); CaDB.Error != nil {
		return Information, CaDB.Error
	}

	// Find the Profile
	var profile Profile
	if ProfileDB := pfpki.DB.Model(&cert).Related(&profile); ProfileDB.Error != nil {
		return Information, ProfileDB.Error
	}

	intreason, err := strconv.Atoi(reason)
	if err != nil {
		return Information, errors.New("Reason unsupported")
	}
	if err := pfpki.DB.Create(&RevokedCert{Cn: cert.Cn, Mail: cert.Mail, Ca: ca, StreetAddress: cert.StreetAddress, Organisation: cert.Organisation, Country: cert.Country, State: cert.State, Locality: cert.Locality, PostalCode: cert.Locality, Key: cert.Key, Cert: cert.Cert, ProfileName: cert.ProfileName, Profile: profile, ValidUntil: cert.ValidUntil, Date: cert.Date, Revoked: time.Now(), CRLReason: intreason, SerialNumber: cert.SerialNumber}).Error; err != nil {
		return Information, err
	}
	if err := pfpki.DB.Delete(&cert).Error; err != nil {
		return Information, err
	}
	return Information, nil
}
