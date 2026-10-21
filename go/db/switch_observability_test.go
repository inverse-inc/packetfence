package db

import (
	"testing"
	"time"
)

func TestMarkSwitchAsSeenEmptyIDIsNoop(t *testing.T) {
	// A nil *sql.DB would panic if the function reached db.Exec.
	if err := MarkSwitchAsSeen(nil, ""); err != nil {
		t.Fatalf("empty switch id must be ignored, got %v", err)
	}
}

func TestMarkSwitchAsSeenHonoursNextAllowed(t *testing.T) {
	id := "test-gated-switch"
	shard := switchObservabilityNextAllowed.Shard(id)
	setNextAllowed(shard, id, time.Now().Add(time.Hour), true)

	// Still inside the window: must return without touching the DB (nil *sql.DB).
	if err := MarkSwitchAsSeen(nil, id); err != nil {
		t.Fatalf("expected cached no-op, got %v", err)
	}
}

func TestSetNextAllowedNeverShortensUnlessForced(t *testing.T) {
	id := "test-backoff-switch"
	shard := switchObservabilityNextAllowed.Shard(id)
	later := time.Now().Add(time.Minute)
	sooner := time.Now().Add(10 * time.Second)

	setNextAllowed(shard, id, later, true)
	setNextAllowed(shard, id, sooner, false)
	if got, _ := shard.Get(id); !got.Equal(later) {
		t.Fatalf("error backoff must not shorten a longer window: got %v want %v", got, later)
	}

	// An error backoff on an unknown or expired id does take effect.
	setNextAllowed(shard, id, later.Add(time.Minute), false)
	if got, _ := shard.Get(id); !got.Equal(later.Add(time.Minute)) {
		t.Fatalf("later deadline must be stored: got %v", got)
	}

	// A successful upsert overrides whatever is stored.
	setNextAllowed(shard, id, sooner, true)
	if got, _ := shard.Get(id); !got.Equal(sooner) {
		t.Fatalf("forced set must win: got %v want %v", got, sooner)
	}
}
