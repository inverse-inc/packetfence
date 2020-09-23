package util

import (
	"testing"
	"time"
)

func TestNormalizeTime(t *testing.T) {
	NORMALIZE_TIME_TESTS := []struct {
		in  string
		out int
		msg string
	}{
		{
			in:  "",
			out: 0,
			msg: "nil normalize attempt",
		},
		{
			in:  "5Z",
			out: 5,
			msg: "illegal normalize attempt",
		},
		{
			in:  "5",
			out: 5,
			msg: "normalizing w/o a time resolution specified (seconds assumed)",
		},
		{
			in:  "2s",
			out: 2 * 1,
			msg: "normalizing seconds",
		},
		{
			in:  "2m",
			out: 2 * 60,
			msg: "normalizing minutes",
		},
		{
			in:  "2h",
			out: 2 * 60 * 60,
			msg: "normalizing hours",
		},
		{
			in:  "2D",
			out: 2 * 24 * 60 * 60,
			msg: "normalizing days",
		},
		{
			in:  "2W",
			out: 2 * 7 * 24 * 60 * 60,
			msg: "normalizing weeks",
		},
		{
			in:  "2M",
			out: 2 * 30 * 24 * 60 * 60,
			msg: "normalizing months",
		},
		{
			in:  "2Y",
			out: 2 * 365 * 24 * 60 * 60,
			msg: "normalizing years",
		},
	}
	for _, test := range NORMALIZE_TIME_TESTS {
		out, _ := NormalizeTime(test.in)
		if out != time.Second*time.Duration(test.out) {
			t.Errorf("Got %d expected %d : %s", out, time.Second*time.Duration(test.out), test.msg)
		}
	}
}
