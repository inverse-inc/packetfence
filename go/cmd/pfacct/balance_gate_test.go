package main

import (
	"testing"
	"time"

	"github.com/inverse-inc/go-utils/mac"
)

// The gate is deployment-wide, so this asserts the transitions its own node
// causes rather than an absolute value: it must never clear balances belonging
// to other nodes, which on a real PacketFence database would destroy every
// guest's remaining time and bandwidth.
func TestBalancesInUseGate(t *testing.T) {
	pfAcct := NewPfAcct("INFO")
	if pfAcct == nil {
		t.Fatalf("New pfAcct")
	}
	t.Cleanup(pfAcct.stopBalancesInUseRefresher)

	m, _ := mac.NewFromString("99:77:55:44:33:25")
	removeNode := func() {
		if _, err := pfAcct.Db.Exec("DELETE FROM node WHERE mac = ?", m.String()); err != nil {
			t.Fatalf("%s", err.Error())
		}
	}

	removeNode()
	t.Cleanup(removeNode)

	// Whatever the rest of the database holds is the baseline this test must
	// return to; only the test node is added and removed.
	pfAcct.refreshBalancesInUse()
	baseline := pfAcct.balancesInUse.Load()

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

	removeNode()
	pfAcct.refreshBalancesInUse()
	if got := pfAcct.balancesInUse.Load(); got != baseline {
		t.Errorf("balancesInUse = %v after the balance-carrying node is gone, want the baseline %v", got, baseline)
	}
}

// A session with no NodeSessionCache entry may only be charged for the time
// since the gate reopened, and only when it actually did reopen: a deployment
// that had balances all along must keep charging exactly as it did before.
func TestUntrackedChargeCap(t *testing.T) {
	enabledFromTheStart := &PfAcct{}
	enabledFromTheStart.balancesInUse.Store(true)
	enabledFromTheStart.setBalancesInUse(true)
	if _, capped := enabledFromTheStart.untrackedChargeCap(); capped {
		t.Error("a gate that was never shut must not cap what a session is charged")
	}

	reopened := &PfAcct{}
	reopened.balancesInUse.Store(true)
	reopened.setBalancesInUse(false)
	if reopened.balancesInUse.Load() {
		t.Fatal("the gate should be shut after a probe finds no balances")
	}

	if _, capped := reopened.untrackedChargeCap(); capped {
		t.Error("a shut gate has nothing to cap yet")
	}

	reopened.setBalancesInUse(true)
	cap, capped := reopened.untrackedChargeCap()
	if !capped {
		t.Fatal("reopening the gate must cap what untracked sessions are charged")
	}

	if cap < 0 || cap > 5 {
		t.Errorf("cap = %ds just after the gate reopened, want ~0", cap)
	}

	// Reopening again while already open must not move the instant.
	before := reopened.balancesEnabledAt.Load()
	time.Sleep(10 * time.Millisecond)
	reopened.setBalancesInUse(true)
	if after := reopened.balancesEnabledAt.Load(); after != before {
		t.Errorf("a probe that keeps the gate open moved the instant from %d to %d", before, after)
	}
}

func TestStopBalancesInUseRefresher(t *testing.T) {
	// Never started: must not panic on a nil channel.
	(&PfAcct{}).stopBalancesInUseRefresher()

	// Started with no database: the probe fails open and the goroutine stops.
	h := &PfAcct{}
	h.startBalancesInUseRefresher()
	if !h.balancesInUse.Load() {
		t.Error("the gate should fail open when the probe cannot run")
	}

	h.stopBalancesInUseRefresher()
	h.stopBalancesInUseRefresher()
}
