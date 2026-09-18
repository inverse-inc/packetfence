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

// balancesEnabledAt has to be stored before the gate is published: a worker
// that sees the gate open while the instant is still 0 gets no cap from
// untrackedChargeCap and charges the whole AcctSessionTime. Racing a goroutine
// against that window does not work -- it is a couple of instructions wide and
// such a test passes against the wrong order -- so observe the order directly,
// through what is already published when the instant is read.
func TestBalancesEnabledAtIsStoredBeforeTheGateOpens(t *testing.T) {
	h := &PfAcct{}
	h.balancesInUse.Store(true)
	h.setBalancesInUse(false)

	gateAlreadyOpen := false
	balanceGateNow = func() time.Time {
		gateAlreadyOpen = h.balancesInUse.Load()
		return time.Now()
	}
	t.Cleanup(func() { balanceGateNow = time.Now })

	h.setBalancesInUse(true)

	if gateAlreadyOpen {
		t.Error("the gate was published before balancesEnabledAt was stored, leaving a window with no charge cap")
	}
	if h.balancesEnabledAt.Load() == 0 {
		t.Error("reopening the gate did not record the instant")
	}
}

// The cap has to bite whether or not a NodeSessionCache entry survived the
// shutdown: an entry outlives a gate-shut window shorter than its idle timeout,
// and the offset it carries predates the shutdown.
func TestCapCharge(t *testing.T) {
	neverShut := &PfAcct{}
	neverShut.balancesInUse.Store(true)
	neverShut.setBalancesInUse(true)
	if got := neverShut.capCharge(86400); got != 86400 {
		t.Errorf("capCharge = %d on a gate that was never shut, want the charge untouched (86400)", got)
	}

	reopened := &PfAcct{}
	reopened.balancesInUse.Store(true)
	reopened.setBalancesInUse(false)
	reopened.setBalancesInUse(true)

	// A whole day of session time, of which only the moments since the gate
	// reopened were ever accounted for.
	if got := reopened.capCharge(86400); got > 5 {
		t.Errorf("capCharge = %d just after the gate reopened, want ~0", got)
	}

	// A charge already within the cap is left alone rather than raised to it.
	if got := reopened.capCharge(0); got != 0 {
		t.Errorf("capCharge = %d for a zero charge, want 0", got)
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
