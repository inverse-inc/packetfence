//go:build !cgo

package hsm

import (
	"crypto"
	"errors"
)

// PKCS#11 modules are loaded through cgo: without it, CAs can't use an HSM.
var errNoCgo = errors.New("hsm: this build of pfpki has no PKCS#11 support (built without cgo)")

func Check(cfg Config) error { return errNoCgo }

func Release(cfg Config) {}

func GenerateKey(cfg Config, keyType KeyType, size int, label string) (crypto.Signer, []byte, error) {
	return nil, nil, errNoCgo
}

func FindKey(cfg Config, id []byte) (crypto.Signer, error) {
	return nil, errNoCgo
}
