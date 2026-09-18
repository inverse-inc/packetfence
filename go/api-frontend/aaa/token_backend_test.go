package aaa

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/VividCortex/mysqlerr"
	"github.com/davecgh/go-spew/spew"
	"github.com/go-sql-driver/mysql"
)

func TestIsRetryableTouchErr(t *testing.T) {
	for _, test := range []struct {
		name string
		err  error
		want bool
	}{
		{"nil", nil, false},
		{"non-mysql error", errors.New("connection refused"), false},
		{"deadlock", &mysql.MySQLError{Number: mysqlerr.ER_LOCK_DEADLOCK, Message: "Deadlock found when trying to get lock"}, true},
		{"lock wait timeout", &mysql.MySQLError{Number: mysqlerr.ER_LOCK_WAIT_TIMEOUT, Message: "Lock wait timeout exceeded"}, true},
		{"other mysql error", &mysql.MySQLError{Number: mysqlerr.ER_UNKNOWN_COM_ERROR, Message: "WSREP has not yet prepared node for application use"}, false},
		{"wrapped deadlock", fmt.Errorf("touch: %w", &mysql.MySQLError{Number: mysqlerr.ER_LOCK_DEADLOCK}), true},
	} {
		if got := isRetryableTouchErr(test.err); got != test.want {
			t.Errorf("isRetryableTouchErr(%s) = %v, want %v", test.name, got, test.want)
		}
	}
}

func TestTouchGranularity(t *testing.T) {
	for _, test := range []struct {
		timeout time.Duration
		want    time.Duration
	}{
		{30 * time.Minute, time.Minute},     // capped
		{10 * time.Minute, time.Minute},     // cap boundary
		{30 * time.Second, 3 * time.Second}, // proportional
		{5 * time.Second, time.Second},      // floored
		{0, time.Second},                    // degenerate config
	} {
		if got := touchGranularity(test.timeout); got != test.want {
			t.Errorf("touchGranularity(%v) = %v, want %v", test.timeout, got, test.want)
		}
	}
}

func TestTokenBackend(t *testing.T) {
	timeout := 1 * time.Second
	expiration := 1 * time.Second
	for _, test := range []struct {
		name string
		b    TokenBackend
	}{
		{"MemTokenBackend", NewMemTokenBackend(timeout, expiration, []string{})},
		{"RedisTokenBackend", NewRedisTokenBackend(timeout, expiration, []string{})},
		{"DbTokenBackend", NewDbTokenBackend(timeout, expiration, []string{})},
		{
			"MultiTokenBackend BlackHole+MemTokenBackend",
			NewMultiTokenBackend(
				NewBlackhole(),
				NewMemTokenBackend(timeout, expiration, []string{}),
			),
		},
		{
			"MultiTokenBackend DbTokenBackend+MemTokenBackend",
			NewMultiTokenBackend(
				NewDbTokenBackend(timeout, expiration, []string{}),
				NewMemTokenBackend(timeout, expiration, []string{}),
			),
		},
	} {
		b := test.b
		t.Run(test.name, func(t *testing.T) {
			token := "my-beautiful-token"
			ctx := context.Background()
			if b.TokenIsValid(token) {
				t.Error("Non existing token is invalid")
			}

			roles := b.AdminActionsForToken(ctx, token)

			if len(roles) != 0 {
				t.Error("Got some roles for an existant token", spew.Sdump(roles))
			}

			b.StoreTokenInfo(token, &TokenInfo{
				AdminRoles: map[string]bool{
					"Node Manager": true,
				},
			})

			if !b.TokenIsValid(token) {
				t.Error("Existing token is not valid")
			}

			roles = b.AdminActionsForToken(ctx, token)

			if len(roles) != 4 {
				t.Error("Got the wrong amount of roles for an existant token", spew.Sdump(roles))
			}

			// Test the expiration
			time.Sleep(expiration + 100*time.Millisecond)

			if b.TokenIsValid(token) {
				t.Error("Non existing token is invalid")
			}

			roles = b.AdminActionsForToken(ctx, token)

			if len(roles) != 0 {
				t.Error("Got some roles for an expired token", spew.Sdump(roles))
			}
		},
		)
	}

}

type Blackhole struct {
}

func NewBlackhole() TokenBackend {
	return &Blackhole{}
}

func (tb *Blackhole) TokenInfoForToken(token string) (*TokenInfo, time.Time) {
	return nil, time.Unix(0, 0)
}

func (tb *Blackhole) StoreTokenInfo(token string, ti *TokenInfo) error {
	return nil
}

func (tb *Blackhole) TokenIsValid(token string) bool {
	return false
}

func (tb *Blackhole) TouchTokenInfo(token string) {
}

func (tb *Blackhole) InvalidateToken(token string) {
}

func (tb *Blackhole) Type() string {
	return "blackhole"
}

func (tb *Blackhole) AdminActionsForToken(ctx context.Context, token string) map[string]bool {
	return nil
}

var _ TokenBackend = (*Blackhole)(nil)
