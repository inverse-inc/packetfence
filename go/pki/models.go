package main

import (
	"bytes"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"math/big"
	"strconv"
	"time"

	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/mysql"
)

// CA struct
type CA struct {
	gorm.Model
	Cn                  string   `json:"cn"`
	Mail                []string `json:"mail"`
	Organisation        []string `json:"organisation"`
	Country             []string `json:"country"`
	State               []string `json:"state"`
	Locality            []string `json:"locality"`
	StreatAddress       []string `json:"streataddress"`
	PostalCode          []string `json:"postalcode"`
	KeyType             int      `json:"keytype"`
	KeySize             int      `json:"keysize"`
	Digest              string   `json:"digest"`
	KeyUsage            []string `json:"keyusage,omitempty"`
	ExtendedKeyUsage    []string `json:"extendedkeyusage,omitempty"`
	Days                int      `json:"days"`
	CaKey               string   `json:"cakey,omitempty"`
	CaCert              string   `json:"cacert,omitempty"`
	IssuerKeyHashmd5    string   `json:"issuerkeyhashmd5,omitempty"`
	IssuerKeyHashsha1   string   `json:"issuerkeyhashsha1,omitempty"`
	IssuerKeyHashsha256 string   `json:"issuerkeyhashsha256,omitempty"`
	IssuerKeyHashsha512 string   `json:"issuerkeyhashsha512,omitempty"`
}

func (c *CA) new() {

	ca := &x509.Certificate{
		SerialNumber: big.NewInt(1653),
		Subject: pkix.Name{
			Organization:  c.Organisation,
			Country:       c.Country,
			Province:      c.State,
			Locality:      c.Locality,
			StreetAddress: c.StreatAddress,
			PostalCode:    c.PostalCode,
		},
		NotBefore:             time.Now(),
		NotAfter:              time.Now().AddDate(0, 0, c.Days),
		IsCA:                  true,
		ExtKeyUsage:           c.extkeyusage(),
		KeyUsage:              x509.KeyUsage(c.keyusage()),
		BasicConstraintsValid: true,
		EmailAddresses:        c.Mail,
	}

	// TODO DSA
	priv, _ := rsa.GenerateKey(rand.Reader, c.KeySize)

	pub := &priv.PublicKey
	caBytes, err := x509.CreateCertificate(rand.Reader, ca, ca, pub, priv)
	if err != nil {
		log.LoggerWContext(ctx).Error("create ca failed", err)
		return
	}

	db, err := gorm.Open("mysql", db.ReturnURI)
	defer db.Close()
	db.AutoMigrate(&CA{})

	cert := new(bytes.Buffer)
	keyOut := new(bytes.Buffer)
	// Public key
	pem.Encode(cert, &pem.Block{Type: "CERTIFICATE", Bytes: caBytes})

	// Private key
	pem.Encode(keyOut, &pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(priv)})

	db.Create(&CA{Cn: c.Cn, Mail: c.Mail, Organisation: c.Organisation, Country: c.Country, State: c.State, Locality: c.Locality, StreatAddress: c.StreatAddress, PostalCode: c.PostalCode, KeyType: c.KeyType, KeySize: c.KeySize, Digest: c.Digest, KeyUsage: c.KeyUsage, ExtendedKeyUsage: c.ExtendedKeyUsage, Days: c.Days, CaKey: keyOut.String(), CaCert: cert.String(), IssuerKeyHashmd5: c.IssuerKeyHashmd5, IssuerKeyHashsha1: c.IssuerKeyHashsha1, IssuerKeyHashsha256: c.IssuerKeyHashsha256, IssuerKeyHashsha512: c.IssuerKeyHashsha512})

}

func (c *CA) extkeyusage() []x509.ExtKeyUsage {
	// Set up extra key uses for certificate
	extKeyUsage := make([]x509.ExtKeyUsage, 0)
	for _, use := range c.ExtendedKeyUsage {
		v, _ := strconv.Atoi(use)
		extKeyUsage = append(extKeyUsage, x509.ExtKeyUsage(v))
	}

	return extKeyUsage
}

func (c *CA) keyusage() int {
	keyUsage := 0
	for _, use := range c.KeyUsage {
		v, _ := strconv.Atoi(use)
		keyUsage = keyUsage | v
	}

	return keyUsage
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

// Profile struct
type Profile struct {
	gorm.Model
	Name     string `json:"profile_name,omitempty"`
	Ca       CA
	Validity string `json:"validity,omitempty"`
	KeyType  string `json:"keytype,omitempty"`
	KeySize  string `json:"keysize,omitempty"`
	// Digest           string `json:"digest,omitempty"`
	KeyUsage         string `json:"keyusage,omitempty"`
	ExtendedKeyUsage string `json:"extendedkeyusage,omitempty"`
	P12SmtpServer    string `json:"p12smtpserver,omitempty"`
	P12MailPassword  string `json:"p12mailpassword,omitempty"`
	P12MailSubject   string `json:"p12mailsubject,omitempty"`
	P12MailFrom      string `json:"p12mailfrom,omitempty"`
	P12MailHeader    string `json:"p12mailheader,omitempty"`
	P12MailFooter    string `json:"p12mailfooter,omitempty"`
}

// Cert struct
type Cert struct {
	Cn                   string `json:"cn,omitempty"`
	Mail                 string `json:"mail,omitempty"`
	X509                 string `json:"x509,omitempty"`
	Streat               string `json:"streat,omitempty"`
	Organisation         string `json:"organisation,omitempty"`
	Country              string `json:"country,omitempty"`
	PubKey               string `json:"pubkey,omitempty"`
	Profile              Profile
	ValidUntil           string `json:"validuntil,omitempty"`
	Date                 string `json:"date,omitempty"`
	Revoked              string `json:"revoked,omitempty"`
	CRLReason            string `json:"crlreason,omitempty"`
	UserIssuerHashmd5    string `json:"userissuerhashmd5,omitempty"`
	UserIssuerHashsha1   string `json:"userissuerhashsha1,omitempty"`
	UserIssuerHashsha256 string `json:"userissuerhashsha256,omitempty"`
	UserIssuerHashsha512 string `json:"userissuerhashsha512,omitempty"`
}
