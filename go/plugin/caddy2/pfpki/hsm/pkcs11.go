//go:build cgo

package hsm

import (
	"crypto"
	"crypto/elliptic"
	"crypto/rand"
	"errors"
	"fmt"
	"io"
	"strings"
	"sync"

	"github.com/eclipse-keypont/crypto11"
)

var (
	mu       sync.Mutex
	contexts = map[string]contextEntry{}
)

// contextEntry is an open token, with what identifies the token.
type contextEntry struct {
	ctx        *crypto11.Context
	module     string
	tokenLabel string
}

// context returns the PKCS#11 context of the token, opening (and logging
// in to) it on first use. Contexts are shared, so every CA on the same
// token uses the same session pool.
func context(cfg Config) (*crypto11.Context, error) {
	if cfg.Module == "" || cfg.TokenLabel == "" {
		return nil, errors.New("hsm: the PKCS#11 module and the token label are required")
	}
	mu.Lock()
	defer mu.Unlock()
	if entry, ok := contexts[cfg.key()]; ok {
		return entry.ctx, nil
	}
	return openLocked(cfg)
}

// openLocked opens the token and caches its context; mu must be held.
func openLocked(cfg Config) (*crypto11.Context, error) {
	ctx, err := crypto11.Configure(&crypto11.Config{
		Path:       cfg.Module,
		TokenLabel: cfg.TokenLabel,
		Pin:        cfg.Pin,
	})
	if err != nil {
		return nil, fmt.Errorf("hsm: unable to open token %q with %s: %w", cfg.TokenLabel, cfg.Module, err)
	}
	contexts[cfg.key()] = contextEntry{ctx: ctx, module: cfg.Module, tokenLabel: cfg.TokenLabel}
	return ctx, nil
}

// Check opens the token with cfg, which validates the module, the token
// label and the PIN.
//
// PKCS#11 login state is per application and token: while any context
// of the token is open, the token stays logged in and a login with any
// PIN succeeds (crypto11 takes CKR_USER_ALREADY_LOGGED_IN as a success).
// So every context of the token is closed first, which logs it out, and
// the PIN is really checked.
func Check(cfg Config) error {
	if cfg.Module == "" || cfg.TokenLabel == "" {
		return errors.New("hsm: the PKCS#11 module and the token label are required")
	}
	mu.Lock()
	defer mu.Unlock()
	for key, entry := range contexts {
		if entry.module == cfg.Module && entry.tokenLabel == cfg.TokenLabel {
			entry.ctx.Close()
			delete(contexts, key)
		}
	}
	_, err := openLocked(cfg)
	return err
}

// Release closes the context of a token, e.g. after its configuration
// changed. Keys found through it can't be used afterwards.
func Release(cfg Config) {
	mu.Lock()
	defer mu.Unlock()
	if entry, ok := contexts[cfg.key()]; ok {
		entry.ctx.Close()
		delete(contexts, cfg.key())
	}
}

// invalidate closes and forgets ctx after an operation through it failed
// because its session or the token is gone, so the next use reopens the
// token. It does nothing when ctx was already replaced.
func invalidate(cfg Config, ctx *crypto11.Context) {
	mu.Lock()
	defer mu.Unlock()
	if entry, ok := contexts[cfg.key()]; ok && entry.ctx == ctx {
		entry.ctx.Close()
		delete(contexts, cfg.key())
	}
}

// staleSessionErrors are the PKCS#11 errors after which a context can't
// be used any more: its sessions or the token are gone, or the token was
// logged out.
var staleSessionErrors = []string{
	"CKR_SESSION_HANDLE_INVALID",
	"CKR_SESSION_CLOSED",
	"CKR_DEVICE_REMOVED",
	"CKR_DEVICE_ERROR",
	"CKR_TOKEN_NOT_PRESENT",
	"CKR_USER_NOT_LOGGED_IN",
	"CKR_CRYPTOKI_NOT_INITIALIZED",
}

// isStaleSession tells whether err is one of staleSessionErrors. crypto11
// wraps the pkcs11.Error values with messages, whose text names them.
func isStaleSession(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	for _, code := range staleSessionErrors {
		if strings.Contains(msg, code) {
			return true
		}
	}
	return false
}

// tokenKey is a key pair of a token. Its operations drop the context of the
// token when they fail with a stale session, so that the next use opens
// a new one instead of failing until pfpki restarts.
type tokenKey struct {
	crypto.Signer
	cfg Config
	ctx *crypto11.Context
}

func (k *tokenKey) Sign(r io.Reader, digest []byte, opts crypto.SignerOpts) ([]byte, error) {
	sig, err := k.Signer.Sign(r, digest, opts)
	if isStaleSession(err) {
		invalidate(k.cfg, k.ctx)
	}
	return sig, err
}

// decrypterKey is a key that can also decrypt (RSA).
type decrypterKey struct {
	*tokenKey
}

func (k decrypterKey) Decrypt(r io.Reader, msg []byte, opts crypto.DecrypterOpts) ([]byte, error) {
	plain, err := k.Signer.(crypto.Decrypter).Decrypt(r, msg, opts)
	if isStaleSession(err) {
		invalidate(k.cfg, k.ctx)
	}
	return plain, err
}

// wrapKey wraps a key pair found or generated through ctx.
func wrapKey(cfg Config, ctx *crypto11.Context, signer crypto.Signer) crypto.Signer {
	k := &tokenKey{Signer: signer, cfg: cfg, ctx: ctx}
	if _, ok := signer.(crypto.Decrypter); ok {
		return decrypterKey{k}
	}
	return k
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
		if isStaleSession(err) {
			invalidate(cfg, ctx)
		}
		return nil, nil, fmt.Errorf("hsm: unable to generate the key in token %q: %w", cfg.TokenLabel, err)
	}
	return wrapKey(cfg, ctx, key), id, nil
}

// DeleteKey removes the key pair with the given CKA_ID from the token,
// e.g. when the CA it was generated for could not be created.
func DeleteKey(cfg Config, id []byte) error {
	ctx, err := context(cfg)
	if err != nil {
		return err
	}
	key, err := ctx.FindKeyPair(id, nil)
	if err != nil {
		return fmt.Errorf("hsm: unable to look up key %x in token %q: %w", id, cfg.TokenLabel, err)
	}
	if key == nil {
		return nil
	}
	deleter, ok := key.(interface{ Delete() error })
	if !ok {
		return fmt.Errorf("hsm: key %x in token %q can't be deleted", id, cfg.TokenLabel)
	}
	if err := deleter.Delete(); err != nil {
		return fmt.Errorf("hsm: unable to delete key %x in token %q: %w", id, cfg.TokenLabel, err)
	}
	return nil
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
		if isStaleSession(err) {
			invalidate(cfg, ctx)
		}
		return nil, fmt.Errorf("hsm: unable to look up key %x in token %q: %w", id, cfg.TokenLabel, err)
	}
	if key == nil {
		return nil, fmt.Errorf("hsm: no key %x in token %q", id, cfg.TokenLabel)
	}
	return wrapKey(cfg, ctx, key), nil
}
