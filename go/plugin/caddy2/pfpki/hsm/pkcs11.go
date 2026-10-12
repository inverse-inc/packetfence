//go:build cgo

package hsm

import (
	"crypto"
	"crypto/elliptic"
	"crypto/rand"
	"errors"
	"fmt"
	"sync"

	"github.com/eclipse-keypont/crypto11"
)

var (
	mu       sync.Mutex
	contexts = map[string]*crypto11.Context{}
)

// context returns the PKCS#11 context of the token, opening (and logging
// in to) it on first use. Contexts are shared, so every CA on the same
// token uses the same session pool.
func context(cfg Config) (*crypto11.Context, error) {
	if cfg.Module == "" || cfg.TokenLabel == "" {
		return nil, errors.New("hsm: the PKCS#11 module and the token label are required")
	}
	mu.Lock()
	defer mu.Unlock()
	if ctx, ok := contexts[cfg.key()]; ok {
		return ctx, nil
	}
	ctx, err := crypto11.Configure(&crypto11.Config{
		Path:       cfg.Module,
		TokenLabel: cfg.TokenLabel,
		Pin:        cfg.Pin,
	})
	if err != nil {
		return nil, fmt.Errorf("hsm: unable to open token %q with %s: %w", cfg.TokenLabel, cfg.Module, err)
	}
	contexts[cfg.key()] = ctx
	return ctx, nil
}

// Check opens the token, which validates the module, the token label and
// the PIN.
func Check(cfg Config) error {
	_, err := context(cfg)
	return err
}

// Release closes the context of a token, e.g. after its configuration
// changed. Keys found through it can't be used afterwards.
func Release(cfg Config) {
	mu.Lock()
	defer mu.Unlock()
	if ctx, ok := contexts[cfg.key()]; ok {
		ctx.Close()
		delete(contexts, cfg.key())
	}
}

// GenerateKey creates a non-extractable key pair in the token and returns
// it with its new CKA_ID. size is the RSA modulus size, or the ECDSA curve
// size (256, 384 or 521).
func GenerateKey(cfg Config, keyType KeyType, size int, label string) (crypto.Signer, []byte, error) {
	ctx, err := context(cfg)
	if err != nil {
		return nil, nil, err
	}
	id := make([]byte, 16)
	if _, err := rand.Read(id); err != nil {
		return nil, nil, err
	}
	var key crypto.Signer
	switch keyType {
	case RSA:
		if size < 2048 {
			return nil, nil, errors.New("hsm: RSA keys must be at least 2048 bits")
		}
		key, err = ctx.GenerateRSAKeyPairWithLabel(id, []byte(label), size)
	case ECDSA:
		var curve elliptic.Curve
		switch size {
		case 256:
			curve = elliptic.P256()
		case 384:
			curve = elliptic.P384()
		case 521:
			curve = elliptic.P521()
		default:
			return nil, nil, errors.New("hsm: ECDSA keys must be 256, 384 or 521 bits")
		}
		key, err = ctx.GenerateECDSAKeyPairWithLabel(id, []byte(label), curve)
	default:
		return nil, nil, errors.New("hsm: only RSA and ECDSA keys can be generated in an HSM")
	}
	if err != nil {
		return nil, nil, fmt.Errorf("hsm: unable to generate the key in token %q: %w", cfg.TokenLabel, err)
	}
	return key, id, nil
}

// FindKey returns the key pair with the given CKA_ID. RSA keys also
// implement crypto.Decrypter.
func FindKey(cfg Config, id []byte) (crypto.Signer, error) {
	ctx, err := context(cfg)
	if err != nil {
		return nil, err
	}
	key, err := ctx.FindKeyPair(id, nil)
	if err != nil {
		return nil, fmt.Errorf("hsm: unable to look up key %x in token %q: %w", id, cfg.TokenLabel, err)
	}
	if key == nil {
		return nil, fmt.Errorf("hsm: no key %x in token %q", id, cfg.TokenLabel)
	}
	return key, nil
}
