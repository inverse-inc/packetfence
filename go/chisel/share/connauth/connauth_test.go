package connauth

import (
	"testing"
	"time"
)

func TestSignVerify(t *testing.T) {
	now := time.Unix(1_700_000_000, 0)
	h := Sign("conn-a", "secret-a", now)
	if err := Verify("conn-a", "secret-a", h, now.Add(time.Minute)); err != nil {
		t.Fatalf("valid signature refused: %v", err)
	}
	if err := Verify("conn-b", "secret-b", h, now); err != ErrInvalid {
		t.Fatalf("another connector's signature accepted: %v", err)
	}
	if err := Verify("conn-b", "secret-a", h, now); err != ErrInvalid {
		t.Fatalf("id swap accepted: %v", err)
	}
	if err := Verify("conn-a", "secret-a", h, now.Add(MaxSkew+time.Second)); err != ErrStale {
		t.Fatalf("stale signature accepted: %v", err)
	}
	if err := Verify("conn-a", "secret-a", "", now); err != ErrMissing {
		t.Fatalf("missing header: %v", err)
	}
	if err := Verify("conn-a", "", h, now); err != ErrInvalid {
		t.Fatalf("empty secret accepted: %v", err)
	}
	if err := Verify("conn-a", "secret-a", "garbage", now); err != ErrInvalid {
		t.Fatalf("garbage accepted: %v", err)
	}
}
