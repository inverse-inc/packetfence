package clientapi

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/pquerna/otp/totp"
)

func newTestTOTP(t *testing.T) *terminalTOTP {
	t.Helper()
	seedFile := filepath.Join(t.TempDir(), "terminal_totp")
	t.Setenv("PFCONNECTOR_TERMINAL_TOTP_FILE", seedFile)

	tt, err := newTerminalTOTP(context.Background(), "test-connector")
	if err != nil {
		t.Fatalf("newTerminalTOTP: %v", err)
	}
	return tt
}

func currentCode(t *testing.T, tt *terminalTOTP) string {
	t.Helper()
	code, err := totp.GenerateCode(tt.key.Secret(), time.Now())
	if err != nil {
		t.Fatalf("GenerateCode: %v", err)
	}
	return code
}

func TestTerminalTOTPPersistence(t *testing.T) {
	tt := newTestTOTP(t)

	raw, err := os.ReadFile(terminalTOTPFile())
	if err != nil {
		t.Fatalf("seed file not written: %v", err)
	}
	if len(raw) == 0 {
		t.Fatal("seed file is empty")
	}

	// A second init must load the same seed, not generate a new one
	tt2, err := newTerminalTOTP(context.Background(), "test-connector")
	if err != nil {
		t.Fatalf("reloading seed: %v", err)
	}
	if tt.key.Secret() != tt2.key.Secret() {
		t.Fatal("reload generated a different seed")
	}
}

func TestTerminalTOTPValidate(t *testing.T) {
	tt := newTestTOTP(t)

	if err := tt.validate(""); !errors.Is(err, errTOTPMissing) {
		t.Fatalf("empty code: got %v, want errTOTPMissing", err)
	}
	if err := tt.validate("000000"); !errors.Is(err, errTOTPInvalid) {
		t.Fatalf("bad code: got %v, want errTOTPInvalid", err)
	}

	code := currentCode(t, tt)
	if err := tt.validate(code); err != nil {
		t.Fatalf("valid code refused: %v", err)
	}
	// One-time use: the same code is refused inside the replay window
	if err := tt.validate(code); !errors.Is(err, errTOTPReplay) {
		t.Fatalf("replayed code: got %v, want errTOTPReplay", err)
	}
}

func TestTerminalTOTPRequired(t *testing.T) {
	cases := []struct {
		value    string
		required bool
	}{
		{"", true},          // unset: required by default
		{"true", true},      // explicit opt-in
		{"enabled", true},   // explicit opt-in
		{"false", false},    // the only way out
		{"disabled", false}, // the only way out
		{"FALSE", false},    // case-insensitive
		{"flase", true},     // typo: fail closed
	}
	for _, c := range cases {
		t.Setenv("PFCONNECTOR_TERMINAL_TOTP", c.value)
		if got := terminalTOTPRequired(); got != c.required {
			t.Errorf("PFCONNECTOR_TERMINAL_TOTP=%q: got %v, want %v", c.value, got, c.required)
		}
	}
}

func TestTerminalTOTPLockout(t *testing.T) {
	tt := newTestTOTP(t)

	for i := 0; i < totpFailureLimit; i++ {
		if err := tt.validate("000000"); !errors.Is(err, errTOTPInvalid) {
			t.Fatalf("attempt %d: got %v, want errTOTPInvalid", i, err)
		}
	}

	// Locked out now, even for a valid code
	if err := tt.validate(currentCode(t, tt)); !errors.Is(err, errTOTPLocked) {
		t.Fatalf("during lockout: got %v, want errTOTPLocked", err)
	}

	// Once the lockout expires, a valid code goes through again
	tt.mu.Lock()
	tt.lockedUntil = time.Now().Add(-time.Second)
	tt.mu.Unlock()
	if err := tt.validate(currentCode(t, tt)); err != nil {
		t.Fatalf("after lockout: %v", err)
	}
}
