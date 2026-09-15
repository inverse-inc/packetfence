package api

import "testing"

func TestVersionLess(t *testing.T) {
	cases := []struct {
		a, b string
		less bool
	}{
		{"15.2.0", "16.0", true},
		{"16.0.0", "16.0", false},
		{"16.1.0", "16.0", false},
		{"15.2.0", "15.10", true}, // numeric, not lexical
		{"0.0.0-src", "16.0", true},
		{"PacketFence 15.2.0", "PacketFence 16.0.0", true},
		{"garbage", "16.0", false},
		{"15.2.0", "garbage", false},
	}
	for _, c := range cases {
		if got := versionLess(c.a, c.b); got != c.less {
			t.Errorf("versionLess(%q, %q) = %v, want %v", c.a, c.b, got, c.less)
		}
	}
}
