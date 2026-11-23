package ocspresponder

import (
	"crypto"
	"crypto/x509"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"gorm.io/gorm"
)

// SetHSMKeyPair replaces the HSM key lookup until the returned function
// is called.
func SetHSMKeyPair(f func(ca models.CA, db *gorm.DB) (*x509.Certificate, crypto.Signer, error)) (restore func()) {
	old := hsmKeyPair
	hsmKeyPair = f
	return func() { hsmKeyPair = old }
}
