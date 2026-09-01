package main

import (
	"testing"

	"github.com/inverse-inc/go-utils/mac"
)

func TestBalancesInUseGate(t *testing.T) {
	pfAcct := NewPfAcct("INFO")
	if pfAcct == nil {
		t.Fatalf("New pfAcct")
	}

	m, _ := mac.NewFromString("99:77:55:44:33:25")
	if _, err := pfAcct.Db.Exec("DELETE FROM node WHERE mac = ?", m.String()); err != nil {
		t.Fatalf("%s", err.Error())
	}
	if _, err := pfAcct.Db.Exec("UPDATE node SET time_balance = NULL, bandwidth_balance = NULL WHERE time_balance IS NOT NULL OR bandwidth_balance IS NOT NULL"); err != nil {
		t.Fatalf("%s", err.Error())
	}

	pfAcct.refreshBalancesInUse()
	if pfAcct.balancesInUse.Load() {
		t.Errorf("balancesInUse should be false with no balances assigned")
	}

	if _, err := pfAcct.Db.Exec("INSERT INTO node (mac, status, time_balance) VALUES (?, 'unreg', 3600)", m.String()); err != nil {
		t.Fatalf("%s", err.Error())
	}
	pfAcct.refreshBalancesInUse()
	if !pfAcct.balancesInUse.Load() {
		t.Errorf("balancesInUse should be true once a node carries a time balance")
	}

	if _, err := pfAcct.Db.Exec("UPDATE node SET time_balance = NULL, bandwidth_balance = 1000000 WHERE mac = ?", m.String()); err != nil {
		t.Fatalf("%s", err.Error())
	}
	pfAcct.refreshBalancesInUse()
	if !pfAcct.balancesInUse.Load() {
		t.Errorf("balancesInUse should be true once a node carries a bandwidth balance")
	}

	if _, err := pfAcct.Db.Exec("DELETE FROM node WHERE mac = ?", m.String()); err != nil {
		t.Fatalf("%s", err.Error())
	}
	pfAcct.refreshBalancesInUse()
	if pfAcct.balancesInUse.Load() {
		t.Errorf("balancesInUse should be false again after the balance-carrying node is gone")
	}
}
