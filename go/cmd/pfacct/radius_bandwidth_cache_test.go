package main

import (
	"testing"
)

func TestBandwidthCache(t *testing.T) {
	pfAcct := NewPfAcct()
	pfAcct.SetAcctSession(1, 2, &AcctSession{in_bytes: 1, out_bytes: 2})
	s := pfAcct.GetAcctSession(1, 2)
	if s == nil {
		t.Fatalf("Could not find session for 1 2")
	}

	s = pfAcct.GetAcctSession(1, 1)
	if s != nil {
		t.Fatalf("Found a session not set 1 1")
	}
}
