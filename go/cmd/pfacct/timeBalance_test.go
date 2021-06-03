package main

import (
	"github.com/inverse-inc/packetfence/go/mac"
	"testing"
)

func TestMacSesssion(t *testing.T) {
	pfAcct := NewPfAcct()
	if pfAcct == nil {
		t.Fatalf("New pfAcct")
	}

	mac, err := mac.NewFromString("99:77:55:44:33:22")
	if err != nil {
		t.Fatalf(err.Error())
	}

	if _, err := pfAcct.Db.Exec("DELETE FROM node WHERE mac = ?", mac.String()); err != nil {
		t.Fatalf(err.Error())
	}

	if _, err := pfAcct.Db.Exec("INSERT INTO node (tenant_id, mac, time_balance, bandwidth_balance) VALUES (?, ?, ?, ?)", 1, mac.String(), 100, 100); err != nil {
		t.Fatalf(err.Error())
	}

	si := &SwitchInfo{TenantId: 1}
	ns := pfAcct.GetNodeSession(si, mac.String())

	if ns == nil {
		t.Fatalf("Cannot get node session for mac '%s'", mac)
	}

	if ns.timeBalance != 100 || ns.bandwidthBalance != 100 {
		t.Fatalf("Invalid node session for mac '%s'", mac)
	}

	ns = pfAcct.getNodeSessionFromCache(si.TenantId, mac.String())

	if ns.timeBalance != 100 || ns.bandwidthBalance != 100 {
		t.Fatalf("Invalid node session for mac '%s'", mac)
	}

	if updated, err := pfAcct.SoftNodeTimeBalanceUpdate(1, mac, 100); err != nil {
		t.Fatalf(err.Error())
	} else if !updated {
		t.Fatalf("SoftNodeTimeBalanceUpdate failed for '%s'", mac)
	}

	/*
		if _, err := pfAcct.Db.Exec("UPDATE node SET status = 'reg' WHERE tenant_id = ? AND mac = ?", 1, mac); err != nil {
			t.Fatalf(err.Error())
		}
	*/

}
