package clientapi

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/pquerna/otp"
	"github.com/pquerna/otp/totp"
)

// Second factor gating remote terminal activation: a TOTP seed generated and
// persisted on the connector-remote itself. The central server never holds
// the seed; it only relays the 6-digit code typed by the admin, which is
// validated here. Enrollment requires reading the seed file on the box:
// there is deliberately no endpoint serving it, since tunnel traffic reaches
// this API as loopback and could otherwise fetch the seed from central.

const (
	// defaultTerminalTOTPFile persists the otpauth URL. In the combined
	// container /usr/local/pf/conf is the host's
	// /usr/local/pfconnector-remote/conf, so the seed survives upgrades.
	defaultTerminalTOTPFile = "/usr/local/pf/conf/terminal_totp"

	// totpFailureLimit consecutive bad codes lock terminal activation for
	// totpLockoutDuration.
	totpFailureLimit    = 5
	totpLockoutDuration = 5 * time.Minute

	// totpReplayWindow: an accepted code is refused if presented again within
	// this window. The code transits the central server, so treat it as
	// one-time; covers the +/-1 step skew around the 30s period.
	totpReplayWindow = 90 * time.Second
)

var (
	errTOTPMissing = errors.New("missing TOTP code")
	errTOTPLocked  = errors.New("too many invalid TOTP codes, terminal activation is temporarily locked")
	errTOTPReplay  = errors.New("TOTP code already used")
	errTOTPInvalid = errors.New("invalid TOTP code")
)

type terminalTOTP struct {
	key *otp.Key

	mu           sync.Mutex
	failures     int
	lockedUntil  time.Time
	lastCode     string
	lastCodeTime time.Time
}

func terminalTOTPFile() string {
	if path := os.Getenv("PFCONNECTOR_TERMINAL_TOTP_FILE"); path != "" {
		return path
	}
	return defaultTerminalTOTPFile
}

// terminalTOTPRequired reports whether terminal activation requires the TOTP
// second factor. Only an explicit PFCONNECTOR_TERMINAL_TOTP=false (or
// equivalent) turns it off; unset or unrecognized values fail closed to
// required.
func terminalTOTPRequired() bool {
	value := strings.ToLower(strings.TrimSpace(os.Getenv("PFCONNECTOR_TERMINAL_TOTP")))
	if enabled, found := sharedutils.ISENABLED[value]; found {
		return enabled
	}
	return true
}

// newTerminalTOTP loads the persisted seed, generating and persisting one on
// first use. An error means the terminal must stay disabled (fail closed).
func newTerminalTOTP(ctx context.Context, connectorID string) (*terminalTOTP, error) {
	path := terminalTOTPFile()
	if raw, err := os.ReadFile(path); err == nil && strings.TrimSpace(string(raw)) != "" {
		key, err := otp.NewKeyFromURL(strings.TrimSpace(string(raw)))
		if err != nil {
			return nil, fmt.Errorf("invalid TOTP seed in %s: %w", path, err)
		}
		return &terminalTOTP{key: key}, nil
	}

	key, err := totp.Generate(totp.GenerateOpts{
		Issuer:      "PacketFence pfconnector",
		AccountName: connectorID,
	})
	if err != nil {
		return nil, fmt.Errorf("generating TOTP seed: %w", err)
	}
	if err := os.WriteFile(path, []byte(key.URL()+"\n"), 0600); err != nil {
		return nil, fmt.Errorf("persisting TOTP seed to %s: %w", path, err)
	}
	log.LoggerWContext(ctx).Info(fmt.Sprintf("Generated the TOTP seed gating remote terminal access in %s. Enroll its otpauth URL in an authenticator app (local access to the box is required to read it).", path))
	return &terminalTOTP{key: key}, nil
}

// validate checks a 6-digit code against the local seed, enforcing the
// lockout and one-time-use rules.
func (t *terminalTOTP) validate(code string) error {
	code = strings.TrimSpace(code)
	if code == "" {
		return errTOTPMissing
	}

	t.mu.Lock()
	defer t.mu.Unlock()

	if time.Now().Before(t.lockedUntil) {
		return errTOTPLocked
	}
	if code == t.lastCode && time.Since(t.lastCodeTime) < totpReplayWindow {
		return errTOTPReplay
	}
	if !totp.Validate(code, t.key.Secret()) {
		t.failures++
		if t.failures >= totpFailureLimit {
			t.failures = 0
			t.lockedUntil = time.Now().Add(totpLockoutDuration)
		}
		return errTOTPInvalid
	}
	t.failures = 0
	t.lastCode = code
	t.lastCodeTime = time.Now()
	return nil
}
