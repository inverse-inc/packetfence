package main

import (
	"bytes"
	"crypto"
	"crypto/dsa"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"encoding/pem"
	"errors"
	"io"
	"math/big"
	"strconv"
	"time"

	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/mysql"
)

type Type int

type DSAKeyFormat struct {
	Version       int
	P, Q, G, Y, X *big.Int
}

var PRNG io.Reader = rand.Reader

const (
	KEY_UNSUPPORTED Type = iota - 1
	KEY_ECDSA
	KEY_RSA
	KEY_DSA
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
	StreetAddress       []string `json:"streetaddress"`
	PostalCode          []string `json:"postalcode"`
	KeyType             Type     `json:"keytype"`
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
			StreetAddress: c.StreetAddress,
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

	priv, _ := GenerateKey(c.KeyType, c.KeySize)

	var pub crypto.PublicKey

	keyOut := new(bytes.Buffer)

	switch c.KeyType {
	case KEY_RSA:
		pub = &priv.(*rsa.PrivateKey).PublicKey
		// Private key
		pem.Encode(keyOut, &pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(priv.(*rsa.PrivateKey))})

	case KEY_ECDSA:
		pub = &priv.(*ecdsa.PrivateKey).PublicKey
		bytes, _ := x509.MarshalECPrivateKey(priv.(*ecdsa.PrivateKey))
		pem.Encode(keyOut, &pem.Block{Type: "EC PRIVATE KEY", Bytes: bytes})

	case KEY_DSA:
		pub = &priv.(*dsa.PrivateKey).PublicKey
		val := DSAKeyFormat{
			P: priv.(*dsa.PrivateKey).P, Q: priv.(*dsa.PrivateKey).Q, G: priv.(*dsa.PrivateKey).G,
			Y: priv.(*dsa.PrivateKey).Y, X: priv.(*dsa.PrivateKey).X,
		}
		bytes, _ := asn1.Marshal(val)
		pem.Encode(keyOut, &pem.Block{Type: "DSA PRIVATE KEY", Bytes: bytes})
	}
	caBytes, err := x509.CreateCertificate(rand.Reader, ca, ca, pub, priv)
	if err != nil {
		log.LoggerWContext(ctx).Error("create ca failed", err)
		return
	}

	db, err := gorm.Open("mysql", db.ReturnURI)
	defer db.Close()
	db.AutoMigrate(&CA{})

	cert := new(bytes.Buffer)

	// Public key
	pem.Encode(cert, &pem.Block{Type: "CERTIFICATE", Bytes: caBytes})

	db.Create(&CA{Cn: c.Cn, Mail: c.Mail, Organisation: c.Organisation, Country: c.Country, State: c.State, Locality: c.Locality, StreetAddress: c.StreetAddress, PostalCode: c.PostalCode, KeyType: c.KeyType, KeySize: c.KeySize, Digest: c.Digest, KeyUsage: c.KeyUsage, ExtendedKeyUsage: c.ExtendedKeyUsage, Days: c.Days, CaKey: keyOut.String(), CaCert: cert.String(), IssuerKeyHashmd5: c.IssuerKeyHashmd5, IssuerKeyHashsha1: c.IssuerKeyHashsha1, IssuerKeyHashsha256: c.IssuerKeyHashsha256, IssuerKeyHashsha512: c.IssuerKeyHashsha512})

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

// GenerateKey based on the Type and the size.
func GenerateKey(keytype Type, size int) (key interface{}, err error) {
	switch keytype {
	case KEY_RSA:
		if size < 2048 {
			return nil, errors.New("invalid private key size")
		}
		var rsakey *rsa.PrivateKey
		rsakey, err = rsa.GenerateKey(PRNG, size)
		if err != nil {
			return
		}
		key = rsakey
	case KEY_ECDSA:
		var eckey *ecdsa.PrivateKey
		switch size {
		case 256:
			eckey, err = ecdsa.GenerateKey(elliptic.P256(), PRNG)
		case 384:
			eckey, err = ecdsa.GenerateKey(elliptic.P384(), PRNG)
		case 521:
			eckey, err = ecdsa.GenerateKey(elliptic.P521(), PRNG)
		default:
			return nil, errors.New("invalid private key size")
		}
		key = eckey
	case KEY_DSA:
		var sizes dsa.ParameterSizes
		switch size {
		case 1024:
			sizes = dsa.L1024N160
		case 2048:
			sizes = dsa.L2048N256
		case 3072:
			sizes = dsa.L3072N256
		default:
			err = errors.New("invalid private key size")
			return
		}

		params := dsa.Parameters{}
		err = dsa.GenerateParameters(&params, rand.Reader, sizes)
		if err != nil {
			return
		}

		dsakey := &dsa.PrivateKey{
			PublicKey: dsa.PublicKey{
				Parameters: params,
			},
		}
		err = dsa.GenerateKey(dsakey, rand.Reader)
		if err != nil {
			return
		}
		key = dsakey
	}

	return
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
	gorm.Model
	Cn                   string  `json:"cn,omitempty"`
	Mail                 string  `json:"mail,omitempty"`
	PrivateKey           string  `json:"privatekey,omitempty"`
	Streat               string  `json:"streat,omitempty"`
	Organisation         string  `json:"organisation,omitempty"`
	Country              string  `json:"country,omitempty"`
	PubKey               string  `json:"publickey,omitempty"`
	Profile              Profile `gorm:"foreignkey:Name"`
	ValidUntil           string  `json:"validuntil,omitempty"`
	Date                 string  `json:"date,omitempty"`
	Revoked              string  `json:"revoked,omitempty"`
	CRLReason            string  `json:"crlreason,omitempty"`
	UserIssuerHashmd5    string  `json:"userissuerhashmd5,omitempty"`
	UserIssuerHashsha1   string  `json:"userissuerhashsha1,omitempty"`
	UserIssuerHashsha256 string  `json:"userissuerhashsha256,omitempty"`
	UserIssuerHashsha512 string  `json:"userissuerhashsha512,omitempty"`
}

// func (c *Cert) new(profile Profile) {

// 	// Load CA
// 	catls, err := tls.LoadX509KeyPair("ca.crt", "ca.key")
// 	if err != nil {
// 		panic(err)
// 	}
// 	ca, err := x509.ParseCertificate(catls.Certificate[0])
// 	if err != nil {
// 		panic(err)
// 	}

// 	// Prepare certificate
// 	cert := &x509.Certificate{
// 		SerialNumber: big.NewInt(1658),
// 		Subject: pkix.Name{
// 			Organization:  []string{"ORGANIZATION_NAME"},
// 			Country:       []string{"COUNTRY_CODE"},
// 			Province:      []string{"PROVINCE"},
// 			Locality:      []string{"CITY"},
// 			StreetAddress: []string{"ADDRESS"},
// 			PostalCode:    []string{"POSTAL_CODE"},
// 		},
// 		NotBefore:    time.Now(),
// 		NotAfter:     time.Now().AddDate(10, 0, 0),
// 		SubjectKeyId: []byte{1, 2, 3, 4, 6},
// 		ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth, x509.ExtKeyUsageServerAuth},
// 		KeyUsage:     x509.KeyUsageDigitalSignature,
// 	}
// 	priv, _ := rsa.GenerateKey(rand.Reader, 2048)
// 	pub := &priv.PublicKey

// 	// Sign the certificate
// 	cert_b, err := x509.CreateCertificate(rand.Reader, cert, ca, pub, catls.PrivateKey)

// 	// Public key
// 	certOut, err := os.Create("bob.crt")
// 	pem.Encode(certOut, &pem.Block{Type: "CERTIFICATE", Bytes: cert_b})
// 	certOut.Close()
// 	log.Print("written cert.pem\n")

// 	// Private key
// 	keyOut, err := os.OpenFile("bob.key", os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
// 	pem.Encode(keyOut, &pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(priv)})
// 	keyOut.Close()
// 	log.Print("written key.pem\n")
// }
