package models

import (
	"crypto"
	"crypto/tls"
	"crypto/x509"
	"encoding/hex"
	"encoding/pem"
	"errors"
	"fmt"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/hsm"
	"gorm.io/gorm"
)

// InHSM tells whether the CA key is held in an HSM.
func (c CA) InHSM() bool {
	return c.HsmID != 0
}

// Certificate parses the CA certificate.
func (c CA) Certificate() (*x509.Certificate, error) {
	block, _ := pem.Decode([]byte(c.Cert))
	if block == nil || block.Type != "CERTIFICATE" {
		return nil, fmt.Errorf("CA %q: no PEM certificate", c.Cn)
	}
	return x509.ParseCertificate(block.Bytes)
}

// KeyPair returns the CA certificate and its private key: the HSM key
// when the CA is held in an HSM, the PEM key otherwise. db loads the HSM
// settings.
func (c CA) KeyPair(db *gorm.DB) (*x509.Certificate, crypto.Signer, error) {
	if !c.InHSM() {
		catls, err := tls.X509KeyPair([]byte(c.Cert), []byte(c.Key))
		if err != nil {
			return nil, nil, err
		}
		cacert, err := x509.ParseCertificate(catls.Certificate[0])
		if err != nil {
			return nil, nil, err
		}
		key, ok := catls.PrivateKey.(crypto.Signer)
		if !ok {
			return nil, nil, fmt.Errorf("CA %q: unsupported private key type %T", c.Cn, catls.PrivateKey)
		}
		return cacert, key, nil
	}

	cacert, err := c.Certificate()
	if err != nil {
		return nil, nil, err
	}
	key, err := c.hsmKey(db)
	if err != nil {
		return nil, nil, err
	}
	if err := sameKey(cacert.PublicKey, key.Public()); err != nil {
		return nil, nil, fmt.Errorf("CA %q: %w", c.Cn, err)
	}
	return cacert, key, nil
}

// hsmKey looks up the CA key pair in its HSM.
func (c CA) hsmKey(db *gorm.DB) (crypto.Signer, error) {
	var h HSM
	if err := db.First(&h, c.HsmID).Error; err != nil {
		return nil, fmt.Errorf("CA %q: HSM %d: %w", c.Cn, c.HsmID, err)
	}
	id, err := hex.DecodeString(c.HsmKeyID)
	if err != nil || len(id) == 0 {
		return nil, fmt.Errorf("CA %q: invalid HSM key id %q", c.Cn, c.HsmKeyID)
	}
	return hsm.FindKey(h.Config(), id)
}

// generateHSMKey creates the key of a new CA in its HSM.
func (c CA) generateHSMKey(db *gorm.DB) (crypto.Signer, []byte, error) {
	var keyType hsm.KeyType
	switch *c.KeyType {
	case certutils.KEY_RSA:
		keyType = hsm.RSA
	case certutils.KEY_ECDSA:
		keyType = hsm.ECDSA
	default:
		return nil, nil, errors.New("only RSA and ECDSA CA keys can be held in an HSM")
	}
	var h HSM
	if err := db.First(&h, c.HsmID).Error; err != nil {
		return nil, nil, fmt.Errorf("HSM %d: %w", c.HsmID, err)
	}
	return hsm.GenerateKey(h.Config(), keyType, c.KeySize, "pfpki CA "+c.Cn)
}

// sameKey checks that a certificate public key is the one of key.
func sameKey(certPub, keyPub crypto.PublicKey) error {
	if k, ok := certPub.(interface{ Equal(crypto.PublicKey) bool }); ok && k.Equal(keyPub) {
		return nil
	}
	return errors.New("the certificate doesn't match the private key")
}

// checkCertMatchesKey verifies that certPEM is a certificate for the CA
// key, as tls.X509KeyPair does for PEM keys.
func (c CA) checkCertMatchesKey(db *gorm.DB, certPEM string) error {
	if !c.InHSM() {
		_, err := tls.X509KeyPair([]byte(certPEM), []byte(c.Key))
		return err
	}
	cert, err := CA{Cn: c.Cn, Cert: certPEM}.Certificate()
	if err != nil {
		return err
	}
	key, err := c.hsmKey(db)
	if err != nil {
		return err
	}
	return sameKey(cert.PublicKey, key.Public())
}
