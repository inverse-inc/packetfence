package maint

import (
	"context"
	"testing"
)

func TestKafkaSubmitter(t *testing.T) {
	jobsConfig := GetMaintenanceConfig(context.Background())
	SetupKafka(jobsConfig["pfflow"].(map[string]interface{}))
}

func TestIsStrandedOffset(t *testing.T) {
	cases := []struct {
		name            string
		committed, last int64
		brokerConfirmed bool
		want            bool
	}{
		{"no committed offset (-1) on a live partition", -1, 100, false, false},
		{"no committed offset (-1) on an empty partition", -1, 0, false, false},
		{"no committed offset (-1), broker confirmed", -1, 0, true, false},
		{"committed behind the log end", 50, 100, false, false},
		{"committed behind the log end, broker confirmed (kafka-go skips ahead itself)", 50, 100, true, false},
		{"committed equals the log end (caught up)", 100, 100, false, false},
		{"caught up on an empty partition", 0, 0, true, false},
		{"committed past the log end: topic recreated", 5_000_000, 110_000, false, true},
		{"committed past the log end, broker confirmed", 5_000_000, 110_000, true, true},
		{"negative log end must never rewind", 5_000_000, -1, false, false},
		{"negative log end must never rewind even when broker confirmed", 5_000_000, -1, true, false},
		{"log end 0 from a periodic/idle check: absent partition or empty topic, must not rewind", 5_000_000, 0, false, false},
		{"log end 0 after the broker answered OffsetOutOfRange: empty recreated topic, reset", 5_000_000, 0, true, true},
	}
	for _, c := range cases {
		if got := isStrandedOffset(c.committed, c.last, c.brokerConfirmed); got != c.want {
			t.Errorf("%s: isStrandedOffset(%d, %d, %v) = %v, want %v", c.name, c.committed, c.last, c.brokerConfirmed, got, c.want)
		}
	}
}
