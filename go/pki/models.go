package main

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"math/big"
	"os"
	"time"

	"github.com/inverse-inc/packetfence/go/log"
	"github.com/jinzhu/gorm"
)

// CA struct
type CA struct {
	gorm.Model
	cn                  string
	mail                string
	organisation        []string
	country             []string
	state               []string
	locality            []string
	streatAddress       []string
	postalCode          []string
	keyType             int
	keySize             int
	digest              string
	keyUsage            string
	extendedKeyUsage    string
	days                int
	caKey               string
	caCert              string
	issuerKeyHashmd5    string
	issuerKeyHashsha1   string
	issuerKeyHashsha256 string
	issuerKeyHashsha512 string
}

func (c CA) sign() {

	ca := &x509.Certificate{
		SerialNumber: big.NewInt(1653),
		Subject: pkix.Name{
			Organization:  c.organisation,
			Country:       c.country,
			Province:      c.state,
			Locality:      c.locality,
			StreetAddress: c.streatAddress,
			PostalCode:    c.postalCode,
		},
		NotBefore:             time.Now(),
		NotAfter:              time.Now().AddDate(10, 0, 0),
		IsCA:                  true,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth, x509.ExtKeyUsageServerAuth},
		KeyUsage:              x509.KeyUsageDigitalSignature | x509.KeyUsageCertSign,
		BasicConstraintsValid: true,
	}

	priv, _ := rsa.GenerateKey(rand.Reader, 2048)
	pub := &priv.PublicKey
	ca_b, err := x509.CreateCertificate(rand.Reader, ca, ca, pub, priv)
	if err != nil {
		log.LoggerWContext(ctx).Error("create ca failed", err)
		return
	}

	// Public key
	certOut, err := os.Create("ca.crt")
	pem.Encode(certOut, &pem.Block{Type: "CERTIFICATE", Bytes: ca_b})
	certOut.Close()
	log.LoggerWContext(ctx).Info("written cert.pem\n")

	// Private key
	keyOut, err := os.OpenFile("ca.key", os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	pem.Encode(keyOut, &pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(priv)})
	keyOut.Close()
	log.LoggerWContext(ctx).Info("written key.pem\n")
}
