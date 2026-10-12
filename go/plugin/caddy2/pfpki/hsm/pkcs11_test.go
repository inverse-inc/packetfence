//go:build cgo

package hsm

import (
	"crypto"
	"crypto/sha256"
	"errors"
	"fmt"
	"io"
	"os"
	"testing"
)

func TestIsStaleSession(t *testing.T) {
	for err, want := range map[error]bool{
		nil: false,
		fmt.Errorf("sign: %w", errors.New("pkcs11: 0xB3: CKR_SESSION_HANDLE_INVALID")): true,
		errors.New("pkcs11: 0x32: CKR_DEVICE_REMOVED"):                                 true,
		errors.New("pkcs11: 0x101: CKR_USER_NOT_LOGGED_IN"):                            true,
		errors.New("pkcs11: 0x68: CKR_MECHANISM_INVALID"):                              false,
	} {
		if got := isStaleSession(err); got != want {
			t.Errorf("isStaleSession(%v) = %v, want %v", err, got, want)
		}
	}
}

// failingSigner fails like a key whose session is gone.
type failingSigner struct{ crypto.Signer }

func (failingSigner) Sign(io.Reader, []byte, crypto.SignerOpts) ([]byte, error) {
	return nil, errors.New("pkcs11: 0xB3: CKR_SESSION_HANDLE_INVALID")
}

// A key failing with a stale session drops the context of the token, and
// the next lookup opens a new one.
func TestStaleSessionReopens(t *testing.T) {
	cfg := Config{
		Module:     os.Getenv("PFPKI_TEST_PKCS11_MODULE"),
		TokenLabel: os.Getenv("PFPKI_TEST_PKCS11_TOKEN"),
		Pin:        os.Getenv("PFPKI_TEST_PKCS11_PIN"),
	}
	if cfg.Module == "" || cfg.TokenLabel == "" {
		t.Skip("PFPKI_TEST_PKCS11_MODULE / PFPKI_TEST_PKCS11_TOKEN not set")
	}
	signer, id, err := GenerateKey(cfg, ECDSA, 256, "pfpki stale session test")
	if err != nil {
		t.Fatal(err)
	}
	defer DeleteKey(cfg, id)
	k := signer.(*tokenKey)
	digest := sha256.Sum256([]byte("test"))

	stale := &tokenKey{Signer: failingSigner{k.Signer}, cfg: cfg, ctx: k.ctx}
	if _, err := stale.Sign(nil, digest[:], crypto.SHA256); err == nil {
		t.Fatal("the failing signer succeeded")
	}
	mu.Lock()
	_, cached := contexts[cfg.key()]
	mu.Unlock()
	if cached {
		t.Fatal("the context was kept after a stale session error")
	}

	again, err := FindKey(cfg, id)
	if err != nil {
		t.Fatalf("FindKey after the context was dropped: %v", err)
	}
	if again.(*tokenKey).ctx == k.ctx {
		t.Fatal("FindKey returned the dropped context")
	}
	if _, err := again.Sign(nil, digest[:], crypto.SHA256); err != nil {
		t.Fatalf("Sign through the new context: %v", err)
	}
}

// A wrong PIN is refused even while the token is logged in.
func TestCheckWrongPinWhileLoggedIn(t *testing.T) {
	cfg := Config{
		Module:     os.Getenv("PFPKI_TEST_PKCS11_MODULE"),
		TokenLabel: os.Getenv("PFPKI_TEST_PKCS11_TOKEN"),
		Pin:        os.Getenv("PFPKI_TEST_PKCS11_PIN"),
	}
	if cfg.Module == "" || cfg.TokenLabel == "" {
		t.Skip("PFPKI_TEST_PKCS11_MODULE / PFPKI_TEST_PKCS11_TOKEN not set")
	}
	if err := Check(cfg); err != nil {
		t.Fatalf("Check with the PIN: %v", err)
	}
	wrong := cfg
	wrong.Pin = "wrong-" + cfg.Pin
	if err := Check(wrong); err == nil {
		t.Fatal("Check accepted a wrong PIN while the token was logged in")
	}
	if err := Check(cfg); err != nil {
		t.Fatalf("Check with the PIN afterwards: %v", err)
	}
}
