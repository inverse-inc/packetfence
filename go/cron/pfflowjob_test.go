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
		want            bool
	}{
		{"no committed offset (-1) on a live partition", -1, 100, false},
		{"committed behind the log end", 50, 100, false},
		{"committed equals the log end (caught up)", 100, 100, false},
		{"committed past the log end: topic recreated", 5_000_000, 110_000, true},
		{"log end unknown / not returned (0) must never rewind", 5_000_000, 0, false},
		{"negative log end must never rewind", 5_000_000, -1, false},
		{"empty recreated partition (log end 0) is left alone until it fills", 5_000_000, 0, false},
	}
	for _, c := range cases {
		if got := isStrandedOffset(c.committed, c.last); got != c.want {
			t.Errorf("%s: isStrandedOffset(%d, %d) = %v, want %v", c.name, c.committed, c.last, got, c.want)
		}
	}
}
