package pool

import (
	"context"
	"github.com/inverse-inc/packetfence/go/log"
	statsd "gopkg.in/alexcesaro/statsd.v2"
	"testing"
)

var ctx = log.LoggerNewContext(context.Background())
var StatsdClient, _ = statsd.New()

func TestReserveIPIndex(t *testing.T) {
	cap := uint64(5)
	algo := Random
	dp := NewDHCPPool(ctx, cap, algo, StatsdClient)

	var err error

	mac := "00:11:22:33:44:55"

	if err != nil {
		t.Error("Not able to parse mac", err)
	}

	// Try to reserve all the IPs
	for i := uint64(0); i < dp.capacity; i++ {
		err, returnedMac := dp.ReserveIPIndex(i, mac)
		if err != nil {
			t.Error("Got an error and shouldn't have gotten one", err)
		}
		if returnedMac != mac {
			t.Error("Returned mac is not the same")
		}

		if free := dp.free[i]; free {
			t.Error("IP is still free although its been reserved")
		}
	}

	// Try to reserve an IP again
	err, _ = dp.ReserveIPIndex(3, mac)

	if err == nil {
		t.Error("Didn't get an error when trying to double-reserve an IP")
	}

	// Try to reserve an IP outside the capacity
	err, _ = dp.ReserveIPIndex(cap, mac)

	if err == nil {
		t.Error("Didn't get an error when trying to reserve an IP outside the capacity")
	}
}

func TestFreeIPIndex(t *testing.T) {
	cap := uint64(5)
	algo := Random
	dp := NewDHCPPool(ctx, cap, algo, StatsdClient)

	var err error
	mac := "00:11:22:33:44:55"

	if err != nil {
		t.Error("Not able to parse mac", err)
	}

	// Try to reserve all the IP, then free all of them
	// Not validating ReserveIPIndex works, this is why TestReserveIPIndex is there
	for i := uint64(0); i < dp.capacity; i++ {
		if _, found := dp.free[i]; !found {
			t.Errorf("IP address %d isn't free at the beginning of the process", i)
		}

		dp.ReserveIPIndex(i, mac)
		err = dp.FreeIPIndex(i)

		if err != nil {
			t.Error("Got an error while freeing IP address", err)
		}

		if _, found := dp.free[i]; !found {
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
	dp := NewDHCPPool(ctx, cap, algo, StatsdClient)

	var err error
	mac := "00:11:22:33:44:55"

	if err != nil {
		t.Error("Not able to parse mac", err)
	}

	order1 := []uint64{}
	seen := map[uint64]bool{}

	for i := uint64(0); i < dp.capacity; i++ {
		index, _, err := dp.GetFreeIPIndex(mac)

		if err != nil {
			t.Error("Error while trying to get a free IP in a non-full pool")
		}

		if _, found := seen[index]; found {
			t.Error("Got previously provided IP index", index)
		}

		if free := dp.free[index]; free {
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
	dp2 := NewDHCPPool(ctx, cap, algo, StatsdClient)

	order2 := []uint64{}

	// Not performing the validation in this loop, that would be replicating the work the first loop above did
	for i := uint64(0); i < dp2.capacity; i++ {
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
	dp := NewDHCPPool(ctx, cap, algo, StatsdClient)

	var expected uint64
	var got uint64

	var err error
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
	dp := NewDHCPPool(ctx, cap, algo, StatsdClient)

	if dp.Capacity() != cap {
		t.Error("Pool capacity not equal the one provided at instantiation")
	}
}
