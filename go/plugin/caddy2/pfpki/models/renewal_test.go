package models

import (
	"testing"
	"time"
)

// Renewal-scheduling tests are kept inside the `models` package so they
// can drive the unexported helpers directly without spinning up the SMTP
// stack. The integration side (CheckRenewal end-to-end) is left to
// manual / staging — the production helper actually dispatches mail.

func TestNextDueRenewalThreshold_SingleValueLegacy(t *testing.T) {
	prof := Profile{DaysBeforeRenewalMail: 7}
	notAfter := time.Now().Add(5 * 24 * time.Hour) // 5 days from now

	cert := Cert{ValidUntil: notAfter}

	t.Run("crossed and never alerted -> due", func(t *testing.T) {
		threshold, oneShot := nextDueRenewalThreshold(time.Now(), cert, prof)
		if threshold != 7 || !oneShot {
			t.Fatalf("got (%d, %v), want (7, true)", threshold, oneShot)
		}
	})

	t.Run("crossed but Alert=true -> nothing", func(t *testing.T) {
		alerted := true
		c := cert
		c.Alert = &alerted
		threshold, oneShot := nextDueRenewalThreshold(time.Now(), c, prof)
		if threshold != -1 || !oneShot {
			t.Fatalf("got (%d, %v), want (-1, true)", threshold, oneShot)
		}
	})

	t.Run("threshold not crossed -> nothing", func(t *testing.T) {
		c := cert
		c.ValidUntil = time.Now().Add(30 * 24 * time.Hour)
		threshold, _ := nextDueRenewalThreshold(time.Now(), c, prof)
		if threshold != -1 {
			t.Fatalf("got %d, want -1", threshold)
		}
	})
}

func TestNextDueRenewalThreshold_MultiSchedule(t *testing.T) {
	prof := Profile{
		DaysBeforeRenewalMail: 14, // ignored when list is set
		RenewalMailDays:       "14,7,1",
	}
	now := time.Now()

	cases := []struct {
		name        string
		daysToExpiry int
		alerted     string
		wantThr     int
	}{
		{"30 days out, nothing sent", 30, "", -1},
		{"10 days out, nothing sent -> 14d due", 10, "", 14},
		{"10 days out, 14 already sent -> nothing yet (7 not crossed)", 10, "14", -1},
		{"6 days out, 14 already sent -> 7 due", 6, "14", 7},
		{"6 days out, 14+7 sent -> nothing (1 not crossed)", 6, "14,7", -1},
		{"0.5 days out, 14+7 sent -> 1 due", 0, "14,7", 1},
		{"0.5 days out, all sent -> nothing", 0, "14,7,1", -1},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			cert := Cert{
				ValidUntil:  now.Add(time.Duration(c.daysToExpiry) * 24 * time.Hour),
				AlertedDays: c.alerted,
			}
			thr, oneShot := nextDueRenewalThreshold(now, cert, prof)
			if oneShot {
				t.Fatalf("oneShot should be false for the multi-schedule path")
			}
			if thr != c.wantThr {
				t.Fatalf("got %d, want %d", thr, c.wantThr)
			}
		})
	}
}

func TestAppendAlertedDay_SortsAndDeduplicates(t *testing.T) {
	cases := []struct {
		in   string
		day  int
		want string
	}{
		{"", 14, "14"},
		{"14", 7, "7,14"},
		{"14,7", 1, "1,7,14"},
		{"14,7,1", 7, "1,7,14"},   // duplicate is a no-op
		{"junk,7", 1, "1,7"},      // bad input is silently dropped
	}
	for _, c := range cases {
		t.Run(c.in+"+"+itoa(c.day), func(t *testing.T) {
			got := appendAlertedDay(c.in, c.day)
			if got != c.want {
				t.Fatalf("got %q, want %q", got, c.want)
			}
		})
	}
}

func TestParseRenewalThresholds(t *testing.T) {
	t.Run("list takes precedence and is sorted ascending", func(t *testing.T) {
		prof := Profile{RenewalMailDays: " 7, 14 , 1 ", DaysBeforeRenewalMail: 30}
		thr, multi := parseRenewalThresholds(prof)
		if !multi {
			t.Fatalf("want multi=true when list is set")
		}
		want := []int{1, 7, 14}
		if !equalInts(thr, want) {
			t.Fatalf("got %v, want %v", thr, want)
		}
	})
	t.Run("empty list falls back to single value", func(t *testing.T) {
		prof := Profile{DaysBeforeRenewalMail: 14}
		thr, multi := parseRenewalThresholds(prof)
		if multi {
			t.Fatalf("want multi=false in legacy path")
		}
		if !equalInts(thr, []int{14}) {
			t.Fatalf("got %v, want [14]", thr)
		}
	})
	t.Run("both empty/zero -> nothing", func(t *testing.T) {
		thr, _ := parseRenewalThresholds(Profile{})
		if len(thr) != 0 {
			t.Fatalf("got %v, want empty", thr)
		}
	})
	t.Run("malformed entries are skipped", func(t *testing.T) {
		prof := Profile{RenewalMailDays: "14,abc,-3,7"}
		thr, _ := parseRenewalThresholds(prof)
		if !equalInts(thr, []int{7, 14}) {
			t.Fatalf("got %v, want [7 14]", thr)
		}
	})
}

func equalInts(a, b []int) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}
