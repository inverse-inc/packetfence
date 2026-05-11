package pool

import (
	"context"
	"database/sql"
	"net"
	"testing"

	"github.com/inverse-inc/go-utils/log"
	"gopkg.in/alexcesaro/statsd.v2"
)

var ctx = log.LoggerNewContext(context.Background())
var StatsdClient, _ = statsd.New()
var MySQLdatabase *sql.DB

func TestReserveIPIndex(t *testing.T) {
	cap := uint64(5)
	algo := Random
	dp, err := Create(ctx, "memory", cap, "PoolTest", algo, StatsdClient, MySQLdatabase)

	if err != nil {
		t.Error("Got an error creating the pool", err)
	}

	mac := "00:11:22:33:44:55"

	if err != nil {
		t.Error("Not able to parse mac", err)
	}

	// Try to reserve all the IPs
	for i := uint64(0); i < dp.GetDHCPPool().capacity; i++ {
		returnedMac, err := dp.ReserveIPIndex(i, mac)
		if err != nil {
			t.Error("Got an error and shouldn't have gotten one", err)
		}
		if returnedMac != mac {
			t.Error("Returned mac is not the same")
		}

		if free := dp.GetDHCPPool().free[i]; free {
			t.Error("IP is still free although its been reserved")
		}
	}

	// Try to reserve an IP again
	_, err = dp.ReserveIPIndex(3, mac)

	if err == nil {
		t.Error("Didn't get an error when trying to double-reserve an IP")
	}

	// Try to reserve an IP outside the capacity
	_, err = dp.ReserveIPIndex(cap, mac)

	if err == nil {
		t.Error("Didn't get an error when trying to reserve an IP outside the capacity")
	}
}

func TestFreeIPIndex(t *testing.T) {
	cap := uint64(5)
	algo := Random
	dp, err := Create(ctx, "memory", cap, "PoolTest", algo, StatsdClient, MySQLdatabase)

	if err != nil {
		t.Error("Got an error creating the pool", err)
	}

	mac := "00:11:22:33:44:55"

	if err != nil {
		t.Error("Not able to parse mac", err)
	}

	// Try to reserve all the IP, then free all of them
	// Not validating ReserveIPIndex works, this is why TestReserveIPIndex is there
	for i := uint64(0); i < dp.GetDHCPPool().capacity; i++ {
		if _, found := dp.GetDHCPPool().free[i]; !found {
			t.Errorf("IP address %d isn't free at the beginning of the process", i)
		}

		dp.ReserveIPIndex(i, mac)
		err = dp.FreeIPIndex(i)

		if err != nil {
			t.Error("Got an error while freeing IP address", err)
		}

		if _, found := dp.GetDHCPPool().free[i]; !found {
			t.Errorf("IP address %d isn't free at the end of the process", i)
		}
	}

	// Try to free an IP again
	err = dp.FreeIPIndex(3)

	if err == nil {
		t.Error("Didn't get an error when trying to double-free an IP")
	}

	// Try to free an IP outside the capacity
	err = dp.FreeIPIndex(cap)

	if err == nil {
		t.Error("Didn't get an error when trying to free an IP outside the capacity")
	}
}

func TestGetFreeIPIndex(t *testing.T) {
	cap := uint64(1000)
	algo := Random
	dp, err := Create(ctx, "memory", cap, "PoolTest", algo, StatsdClient, MySQLdatabase)

	if err != nil {
		t.Error("Got an error creating the pool", err)
	}

	mac := "00:11:22:33:44:55"

	if err != nil {
		t.Error("Not able to parse mac", err)
	}

	order1 := []uint64{}
	seen := map[uint64]bool{}

	for i := uint64(0); i < dp.GetDHCPPool().capacity; i++ {
		index, _, err := dp.GetFreeIPIndex(mac)

		macObj, _ := net.ParseMAC(mac)
		mac = IncrementMAC(macObj).String()

		if err != nil {
			t.Error("Error while trying to get a free IP in a non-full pool")
		}

		if _, found := seen[index]; found {
			t.Error("Got previously provided IP index", index)
		}

		if free := dp.GetDHCPPool().free[index]; free {
			t.Error("IP is still free although its been assigned")
		}

		order1 = append(order1, index)
	}

	// Attempt to get another IP when the pool is full
	_, _, err = dp.GetFreeIPIndex(mac)

	if err == nil {
		t.Error("Didn't get an error when attempting to get a free index in a pool that has reached capacity")
	}

	// No two pool orders should be the same when getting IPs
	// This has a very minimal chance of failing even if the code works
	// If it does, go buy yourself a 6/49
	dp2, err := Create(ctx, "memory", cap, "PoolTest", algo, StatsdClient, MySQLdatabase)
	if err != nil {
		t.Error("Got an error creating the pool", err)
	}

	order2 := []uint64{}

	// Not performing the validation in this loop, that would be replicating the work the first loop above did
	for i := uint64(0); i < dp2.GetDHCPPool().capacity; i++ {
		index, _, _ := dp2.GetFreeIPIndex(mac)
		order2 = append(order2, index)
	}

	same := true
	for i, index := range order1 {
		if order2[i] != index {
			same = false
			break
		}
	}

	if same {
		t.Error("The two orders of IP indexes are the same. The pool should offer indexes at random")
	}
}

func TestFreeIPsRemaining(t *testing.T) {
	cap := uint64(1000)
	algo := Random
	dp, err := Create(ctx, "memory", cap, "PoolTest", algo, StatsdClient, MySQLdatabase)
	if err != nil {
		t.Error("Got an error creating the pool", err)
	}

	var expected uint64
	var got uint64

	mac := "00:11:22:33:44:55"

	if err != nil {
		t.Error("Not able to parse mac", err)
	}
	// No IPs reserved or taken, should match the capacity
	expected = cap
	got = dp.FreeIPsRemaining()
	if expected != got {
		t.Errorf("Missmatch between the free IPs remaining and the expected result. Expected %d and got %d", expected, got)
	}

	// Reserve an IP, should be cap minus 1
	dp.ReserveIPIndex(0, mac)
	expected = cap - 1
	got = dp.FreeIPsRemaining()
	if expected != got {
		t.Errorf("Missmatch between the free IPs remaining and the expected result. Expected %d and got %d", expected, got)
	}

	// Free an IP, should be back to cap
	dp.FreeIPIndex(0)
	expected = cap
	got = dp.FreeIPsRemaining()
	if expected != got {
		t.Errorf("Missmatch between the free IPs remaining and the expected result. Expected %d and got %d", expected, got)
	}

	// Empty the pool, should be 0
	for i := uint64(0); i < cap; i++ {
		dp.GetFreeIPIndex(mac)
		macObj, _ := net.ParseMAC(mac)
		mac = IncrementMAC(macObj).String()
	}

	expected = 0
	got = dp.FreeIPsRemaining()
	if expected != got {
		t.Errorf("Missmatch between the free IPs remaining and the expected result. Expected %d and got %d", expected, got)
	}
}

func TestCapacity(t *testing.T) {
	cap := uint64(1000)
	algo := Random
	dp, err := Create(ctx, "memory", cap, "PoolTest", algo, StatsdClient, MySQLdatabase)
	if err != nil {
		t.Error("Got an error creating the pool", err)
	}

	if dp.Capacity() != cap {
		t.Error("Pool capacity not equal the one provided at instantiation")
	}
}

// TestGetFreeIPIndexOldestReleased exercises the OldestReleased algorithm and
// ensures it never returns an index that is still reserved by another MAC.
// Previously the algorithm iterated `released` directly without filtering by
// `free`, which could pick an already-reserved index and silently overwrite
// its MAC binding.
func TestGetFreeIPIndexOldestReleased(t *testing.T) {
	cap := uint64(10)
	dp, err := Create(ctx, "memory", cap, "PoolTestOldest", OldestReleased, StatsdClient, MySQLdatabase)
	if err != nil {
		t.Fatal("Got an error creating the pool", err)
	}

	macA := "00:11:22:33:44:01"
	macB := "00:11:22:33:44:02"

	// Reserve every index for macA.
	for i := uint64(0); i < cap; i++ {
		if _, err := dp.ReserveIPIndex(i, macA); err != nil {
			t.Fatalf("ReserveIPIndex(%d) failed: %s", i, err)
		}
	}

	// Free one index — that's the only legitimate candidate for the next
	// GetFreeIPIndex call regardless of how stale `released` looks.
	if err := dp.FreeIPIndex(5); err != nil {
		t.Fatalf("FreeIPIndex(5) failed: %s", err)
	}

	idx, _, err := dp.GetFreeIPIndex(macB)
	if err != nil {
		t.Fatalf("GetFreeIPIndex failed: %s", err)
	}
	if idx != 5 {
		t.Fatalf("OldestReleased returned reserved index %d; expected 5 (the only free index)", idx)
	}
	if _, returnedMac, _ := dp.GetMACIndex(idx); returnedMac != macB {
		t.Fatalf("Expected pool.mac[%d]=%s, got %s", idx, macB, returnedMac)
	}

	// macA must still own every other index — the algorithm must not have
	// silently re-bound a reserved slot to macB.
	for i := uint64(0); i < cap; i++ {
		if i == 5 {
			continue
		}
		_, m, _ := dp.GetMACIndex(i)
		if m != macA {
			t.Fatalf("Index %d expected to still be held by %s, got %s", i, macA, m)
		}
	}

	// Pool should now be full.
	if _, _, err := dp.GetFreeIPIndex(macB); err == nil {
		t.Error("Expected pool-is-full error, got nil")
	}
}

func IncrementMAC(mac net.HardwareAddr) net.HardwareAddr {
	inc := make(net.HardwareAddr, len(mac))
	copy(inc, mac)
	for i := len(inc) - 1; i >= 0; i-- {
		inc[i]++
		if inc[i] != 0 {
			break
		}
	}
	return inc
}
