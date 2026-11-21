// Package hsm gives pfpki access to CA keys held in a hardware security
// module through PKCS#11. Keys are generated inside the token as
// sensitive, non-extractable objects and are only ever used through
// crypto.Signer / crypto.Decrypter.
package hsm

import (
	"crypto/sha256"
	"encoding/hex"
)

// Config identifies a PKCS#11 token.
type Config struct {
	// Module is the path of the vendor PKCS#11 library, as seen by pfpki.
	Module string
	// TokenLabel selects the token (or partition) in the module.
	TokenLabel string
	// Pin is the user PIN of the token.
	Pin string
}

func (c Config) key() string {
	h := sha256.Sum256([]byte(c.Module + "\x00" + c.TokenLabel + "\x00" + c.Pin))
	return hex.EncodeToString(h[:])
}

// KeyType is the algorithm of a key generated in the token.
type KeyType int

const (
	RSA KeyType = iota
	ECDSA
)
