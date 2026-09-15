package main

import (
	"testing"

	"github.com/inverse-inc/go-radius/rfc2866"
	"github.com/inverse-inc/go-utils/mac"
)

func sessionIsOnline(pfAcct *PfAcct, m mac.Mac) (bool, bool) {
	var isOnline bool
	err := pfAcct.Db.QueryRow("SELECT is_online FROM node_current_session WHERE mac = ?", m.String()).Scan(&isOnline)
	if err != nil {
		return false, false
	}
	return isOnline, true
}

func TestRateLimitedNodeOnlineOffline(t *testing.T) {
	pfAcct := NewPfAcct("INFO")
	if pfAcct == nil {
		t.Fatalf("New pfAcct")
	}

	m, _ := mac.NewFromString("99:77:55:44:33:26")
	session := uint64(42)
	if _, err := pfAcct.Db.Exec("DELETE FROM node_current_session WHERE mac = ?", m.String()); err != nil {
		t.Fatalf("%s", err.Error())
	}

	if err := pfAcct.rateLimitedNodeOnlineOffline(rfc2866.AcctStatusType_Value_Start, m, session); err != nil {
		t.Fatalf("Start: %s", err.Error())
	}
	if online, found := sessionIsOnline(pfAcct, m); !found || !online {
		t.Fatalf("Session should be online after Start (found=%v online=%v)", found, online)
	}

	// An interim within the TTL is skipped: remove the row behind the cache's
	// back and verify it is not recreated.
	if _, err := pfAcct.Db.Exec("DELETE FROM node_current_session WHERE mac = ?", m.String()); err != nil {
		t.Fatalf("%s", err.Error())
	}
	if err := pfAcct.rateLimitedNodeOnlineOffline(rfc2866.AcctStatusType_Value_InterimUpdate, m, session); err != nil {
		t.Fatalf("Interim: %s", err.Error())
	}
	if _, found := sessionIsOnline(pfAcct, m); found {
		t.Fatalf("Interim within the TTL should have been rate-limited")
	}

	// Stop always executes and clears the cache, so a same-session Start
	// right after goes through and re-marks the node online.
	if err := pfAcct.rateLimitedNodeOnlineOffline(rfc2866.AcctStatusType_Value_Stop, m, session); err != nil {
		t.Fatalf("Stop: %s", err.Error())
	}
	if err := pfAcct.rateLimitedNodeOnlineOffline(rfc2866.AcctStatusType_Value_Start, m, session); err != nil {
		t.Fatalf("Start after Stop: %s", err.Error())
	}
	if online, found := sessionIsOnline(pfAcct, m); !found || !online {
		t.Fatalf("Session should be online again after Stop then Start (found=%v online=%v)", found, online)
	}
}
