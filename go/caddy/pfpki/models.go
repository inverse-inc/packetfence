package pfpki

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

	"github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/mysql"
)

// Type of key
type Type int

// DSAKeyFormat is the format of a DSA key
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
	Cn                  string `json:"cn" gorm:"UNIQUE"`
	Mail                string `json:"mail"`
	Organisation        string `json:"organisation"`
	Country             string `json:"country"`
	State               string `json:"state"`
	Locality            string `json:"locality"`
	StreetAddress       string `json:"streetaddress"`
	PostalCode          string `json:"postalcode"`
	KeyType             Type   `json:"keytype"`
	KeySize             int    `json:"keysize"`
	Digest              string `json:"digest"`
	KeyUsage            string `json:"keyusage,omitempty"`
	ExtendedKeyUsage    string `json:"extendedkeyusage,omitempty"`
	Days                int    `json:"days"`
	CaKey               string `json:"cakey,omitempty" gorm:"type:longtext"`
	CaCert              string `json:"cacert,omitempty" gorm:"type:longtext"`
	IssuerKeyHashmd5    string `json:"issuerkeyhashmd5,omitempty" gorm:"UNIQUE_INDEX"`
	IssuerKeyHashsha1   string `json:"issuerkeyhashsha1,omitempty" gorm:"UNIQUE_INDEX"`
	IssuerKeyHashsha256 string `json:"issuerkeyhashsha256,omitempty" gorm:"UNIQUE_INDEX"`
	IssuerKeyHashsha512 string `json:"issuerkeyhashsha512,omitempty" gorm:"UNIQUE_INDEX"`
}

// Profile struct
type Profile struct {
	gorm.Model
	Name             string `json:"profile_name,omitempty" gorm:"UNIQUE"`
	Ca               CA     `json:"ca,omitempty" gorm:"foreignkey:Cn"`
	Validity         string `json:"validity,omitempty"`
	KeyType          Type   `json:"keytype,omitempty"`
	KeySize          string `json:"keysize,omitempty"`
	Digest           string `json:"digest,omitempty"`
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
	Cn                   string  `json:"cn,omitempty"  gorm:"UNIQUE"`
	Mail                 string  `json:"mail,omitempty"`
	Streat               string  `json:"streat,omitempty"`
	Organisation         string  `json:"organisation,omitempty"`
	Country              string  `json:"country,omitempty"`
	PrivateKey           string  `json:"privatekey,omitempty" gorm:"type:longtext"`
	PubKey               string  `json:"publickey,omitempty" gorm:"type:longtext"`
	Profile              Profile `json:"profile,omitempty" gorm:"foreignkey:Name"`
	ValidUntil           string  `json:"validuntil,omitempty"`
	Date                 string  `json:"date,omitempty"`
	Revoked              string  `json:"revoked,omitempty"`
	CRLReason            string  `json:"crlreason,omitempty"`
	UserIssuerHashmd5    string  `json:"userissuerhashmd5,omitempty" gorm:"UNIQUE_INDEX"`
	UserIssuerHashsha1   string  `json:"userissuerhashsha1,omitempty" gorm:"UNIQUE_INDEX"`
	UserIssuerHashsha256 string  `json:"userissuerhashsha256,omitempty" gorm:"UNIQUE_INDEX"`
	UserIssuerHashsha512 string  `json:"userissuerhashsha512,omitempty" gorm:"UNIQUE_INDEX"`
}

// curl -H "Content-Type: application/json" -d '{"cn":"YZaymCA","mail":"zaym@inverse.ca","organisation": "inverse","country": "CA","state": "QC", "locality": "Montreal", "streetaddress": "7000 avenue du parc", "postalcode": "H3N 1X1", "keytype": 1, "keysize": 2048, "Digest": "md5", "days": 3650}' http://127.0.0.1:12345/api/v1/pki/newca
func (c CA) new(pfpki *Handler) error {

	ca := &x509.Certificate{
		SerialNumber: big.NewInt(1653),
		Subject: pkix.Name{
			Organization:  []string{c.Organisation},
			Country:       []string{c.Country},
			Province:      []string{c.State},
			Locality:      []string{c.Locality},
			StreetAddress: []string{c.StreetAddress},
			PostalCode:    []string{c.PostalCode},
		},
		NotBefore:             time.Now(),
		NotAfter:              time.Now().AddDate(0, 0, c.Days),
		IsCA:                  true,
		ExtKeyUsage:           extkeyusage(c.ExtendedKeyUsage),
		KeyUsage:              x509.KeyUsage(keyusage(c.KeyUsage)),
		BasicConstraintsValid: true,
		EmailAddresses:        []string{c.Mail},
	}

	priv, err := GenerateKey(c.KeyType, c.KeySize)

	if err != nil {
		return err
	}

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
		return errors.New("create ca failed")
	}

	pfpki.DB.AutoMigrate(&CA{})

	cert := new(bytes.Buffer)

	// Public key
	pem.Encode(cert, &pem.Block{Type: "CERTIFICATE", Bytes: caBytes})

	if err := pfpki.DB.Create(&CA{Cn: c.Cn, Mail: c.Mail, Organisation: c.Organisation, Country: c.Country, State: c.State, Locality: c.Locality, StreetAddress: c.StreetAddress, PostalCode: c.PostalCode, KeyType: c.KeyType, KeySize: c.KeySize, Digest: c.Digest, KeyUsage: c.KeyUsage, ExtendedKeyUsage: c.ExtendedKeyUsage, Days: c.Days, CaKey: keyOut.String(), CaCert: cert.String(), IssuerKeyHashmd5: c.IssuerKeyHashmd5, IssuerKeyHashsha1: c.IssuerKeyHashsha1, IssuerKeyHashsha256: c.IssuerKeyHashsha256, IssuerKeyHashsha512: c.IssuerKeyHashsha512}).Error; err != nil {
		return err
	}
	return nil
}

func extkeyusage(ExtendedKeyUsage string) []x509.ExtKeyUsage {
	// Set up extra key uses for certificate
	extKeyUsage := make([]x509.ExtKeyUsage, 0)
	for _, use := range []string{ExtendedKeyUsage} {
		v, _ := strconv.Atoi(use)
		extKeyUsage = append(extKeyUsage, x509.ExtKeyUsage(v))
	}

	return extKeyUsage
}

func keyusage(KeyUsage string) int {
	keyUsage := 0
	for _, use := range []string{KeyUsage} {
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
			return nil, errors.New("invalid private key size, should be at least 2048")
		}
		var rsakey *rsa.PrivateKey
		rsakey, err = rsa.GenerateKey(PRNG, size)
		if err != nil {
			return nil, err
		}
		key = rsakey
	case KEY_ECDSA:
		var eckey *ecdsa.PrivateKey
		switch size {
		case 256:
			eckey, err = ecdsa.GenerateKey(elliptic.P256(), PRNG)
			if err != nil {
				return nil, err
			}
		case 384:
			eckey, err = ecdsa.GenerateKey(elliptic.P384(), PRNG)
			if err != nil {
				return nil, err
			}
		case 521:
			eckey, err = ecdsa.GenerateKey(elliptic.P521(), PRNG)
			if err != nil {
				return nil, err
			}
		default:
			return nil, errors.New("invalid private key size, should be 256 or 384 or 521")
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
			return nil, errors.New("invalid private key size, should be 1024 or 2048 or 3072")
		}

		params := dsa.Parameters{}
		err = dsa.GenerateParameters(&params, rand.Reader, sizes)
		if err != nil {
			return nil, err
		}

		dsakey := &dsa.PrivateKey{
			PublicKey: dsa.PublicKey{
				Parameters: params,
			},
		}
		err = dsa.GenerateKey(dsakey, rand.Reader)
		if err != nil {
			return nil, err
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

// curl -H "Content-Type: application/json" -d '{"name":"ZaymProfile","ca":"YZaymCA","validity": 365,"keytype": 1,"digest": "md5", "keyusage": "", "extendedkeyusage": "", "p12smtpserver": "10.0.0.6", "p12mailpassword": 1, "p12mailsubject": "New certificate", "P12MailFrom": "zaym@inverse.ca", "days": 365}' http://127.0.0.1:12345/api/v1/pki/newprofile
func (p Profile) new(pfpki *Handler) error {
	pfpki.DB.AutoMigrate(&Profile{})

	if err := pfpki.DB.Create(&Profile{Name: p.Name, Ca: p.Ca, Validity: p.Validity, KeyType: p.KeyType, Digest: p.Digest, KeyUsage: p.KeyUsage, ExtendedKeyUsage: p.ExtendedKeyUsage, P12SmtpServer: p.P12SmtpServer, P12MailPassword: p.P12MailPassword, P12MailSubject: p.P12MailSubject, P12MailFrom: p.P12MailFrom, P12MailHeader: p.P12MailHeader, P12MailFooter: p.P12MailFooter}).Error; err != nil {
		return err
	}
	return nil
}

func (c Cert) new(pfpki *Handler) error {
	return nil
}

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
