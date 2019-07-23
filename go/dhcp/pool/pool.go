package pool

import (
	"context"
	"errors"
	"math/rand"
	"sort"
	"strconv"
	"sync"
	"time"

	"github.com/inverse-inc/packetfence/go/log"
	statsd "gopkg.in/alexcesaro/statsd.v2"
)

// FreeMac is the Free Mac address constant
const FreeMac = "00:00:00:00:00:00"

// FakeMac is the Fake Mac address constant
const FakeMac = "ff:ff:ff:ff:ff:ff"

// Random ip constant
const Random = 1

// OldestReleased ip constant
const OldestReleased = 2

// DHCPPool structure
type DHCPPool struct {
	lock      *sync.RWMutex
	free      map[uint64]bool
	mac       map[uint64]string
	capacity  uint64
	released  map[uint64]int64
	algorithm int
	ctx       context.Context
	statsd    *statsd.Client
}

// NewDHCPPool constructor
func NewDHCPPool(context context.Context, capacity uint64, algorithm int, StatsdClient *statsd.Client) *DHCPPool {
	log.SetProcessName("pfdhcp")
	ctx := log.LoggerNewContext(context)
	d := &DHCPPool{
		lock:      &sync.RWMutex{},
		free:      make(map[uint64]bool),
		mac:       make(map[uint64]string),
		released:  make(map[uint64]int64),
		algorithm: algorithm,
		capacity:  capacity,
		ctx:       ctx,
		statsd:    StatsdClient,
	}
	for i := uint64(0); i < d.capacity; i++ {
		d.free[i] = true
		d.released[i] = time.Now().UnixNano()
	}
	return d
}

// GetIssues Compare what we have in the cache with what we have in the pool
func (dp *DHCPPool) GetIssues(macs []string) ([]string, map[uint64]string) {
	dp.lock.RLock()
	defer dp.lock.RUnlock()
	t := dp.statsd.NewTiming()
	defer dp.timeTrack(t, "GetIssues")
	var found bool
	found = false
	var inPoolNotInCache []string
	var duplicateInPool map[uint64]string
	duplicateInPool = make(map[uint64]string)

	var count int
	var saveindex uint64
	for i := uint64(0); i < dp.capacity; i++ {
		if dp.free[i] {
			continue
		}
		for _, mac := range macs {
			if dp.mac[i] == mac {
				found = true
			}
		}
		if !found {
			inPoolNotInCache = append(inPoolNotInCache, dp.mac[i]+", "+strconv.Itoa(int(i)))
		}
	}
	for _, mac := range macs {
		count = 0
		saveindex = 0

		for i := uint64(0); i < dp.capacity; i++ {
			if dp.free[i] {
				continue
			}
			if dp.mac[i] == mac {
				if count == 0 {
					saveindex = i
				}
				if count == 1 {
					duplicateInPool[saveindex] = mac
					duplicateInPool[i] = mac
				} else if count > 1 {
					duplicateInPool[i] = mac
				}
				count++
			}
		}
	}
	return inPoolNotInCache, duplicateInPool
}

// ReserveIPIndex Reserves an IP in the pool, returns an error if the IP has already been reserved
func (dp *DHCPPool) ReserveIPIndex(index uint64, mac string) (string, error) {
	dp.lock.Lock()
	defer dp.lock.Unlock()
	t := dp.statsd.NewTiming()
	defer dp.timeTrack(t, "ReserveIPIndex")
	if index >= dp.capacity {
		return FreeMac, errors.New("Trying to reserve an IP that is outside the capacity of this pool")
	}

	if _, free := dp.free[index]; free {
		delete(dp.free, index)
		dp.mac[index] = mac
		return mac, nil
	}
	return FreeMac, errors.New("IP is already reserved")
}

// FreeIPIndex Frees an IP in the pool, returns an error if the IP is already free
func (dp *DHCPPool) FreeIPIndex(index uint64) error {
	dp.lock.Lock()
	defer dp.lock.Unlock()
	t := dp.statsd.NewTiming()
	defer dp.timeTrack(t, "FreeIPIndex")
	if !dp.IndexInPool(index) {
		return errors.New("Trying to free an IP that is outside the capacity of this pool")
	}

	if _, free := dp.free[index]; free {
		return errors.New("IP is already free")
	}
	dp.free[index] = true
	dp.released[index] = time.Now().UnixNano()
	delete(dp.mac, index)
	return nil
}

// IsFreeIPAtIndex Check if the IP is free at the index
func (dp *DHCPPool) IsFreeIPAtIndex(index uint64) bool {
	dp.lock.RLock()
	defer dp.lock.RUnlock()
	t := dp.statsd.NewTiming()
	defer dp.timeTrack(t, "IsFreeIPAtIndex")
	if !dp.IndexInPool(index) {
		return false
	}

	if _, free := dp.free[index]; free {
		return true
	}
	return false
}

// GetMACIndex Check if the IP is free at the index
func (dp *DHCPPool) GetMACIndex(index uint64) (uint64, string, error) {
	dp.lock.RLock()
	defer dp.lock.RUnlock()
	t := dp.statsd.NewTiming()
	defer dp.timeTrack(t, "GetMACIndex")
	if !dp.IndexInPool(index) {
		return index, FreeMac, errors.New("The index is not part of the pool")
	}

	if _, free := dp.free[index]; free {
		return index, FreeMac, nil
	}
	return index, dp.mac[index], nil
}

// GetFreeIPIndex Returns a random free IP address, an error if the pool is full
func (dp *DHCPPool) GetFreeIPIndex(mac string) (uint64, string, error) {
	dp.lock.Lock()
	defer dp.lock.Unlock()
	t := dp.statsd.NewTiming()
	defer dp.timeTrack(t, "GetFreeIPIndex")
	if len(dp.free) == 0 {
		return 0, FreeMac, errors.New("DHCP pool is full")
	}

	var available uint64

	if dp.algorithm == OldestReleased {

		type kv struct {
			Key   uint64
			Value int64
		}

		var ss []kv
		for k, v := range dp.released {
			ss = append(ss, kv{k, v})
		}

		sort.Slice(ss, func(i, j int) bool {
			return ss[i].Value > ss[j].Value
		})

		for _, kv := range ss {
			available = kv.Key
			break
		}

	} else {
		index := rand.Intn(len(dp.free))
		for available = range dp.free {
			if index == 0 {
				break
			}
			index--
		}
	}

	delete(dp.free, available)
	dp.mac[available] = mac

	return available, mac, nil
}

// IndexInPool Returns whether or not a specific index is in the capacity of the pool
func (dp *DHCPPool) IndexInPool(index uint64) bool {
	t := dp.statsd.NewTiming()
	defer dp.timeTrack(t, "IndexInPool")
	return index < dp.capacity
}

// FreeIPsRemaining Returns the amount of free IPs in the pool
func (dp *DHCPPool) FreeIPsRemaining() uint64 {
	dp.lock.RLock()
	defer dp.lock.RUnlock()
	t := dp.statsd.NewTiming()
	defer dp.timeTrack(t, "FreeIPsRemaining")
	return uint64(len(dp.free))
}

// Capacity Returns the capacity of the pool
func (dp *DHCPPool) Capacity() uint64 {
	t := dp.statsd.NewTiming()
	defer dp.timeTrack(t, "Capacity")
	return dp.capacity
}

// Track timing for each function
func (dp *DHCPPool) timeTrack(t statsd.Timing, name string) {
	t.Send("pfdhcp." + name)

}
