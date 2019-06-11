package pool

import (
	"context"
	"errors"
	"github.com/inverse-inc/packetfence/go/log"
	"math/rand"
	"sort"
	"strconv"
	"sync"
	"time"
)

// FreeMac is the Free Mac address constant
const FreeMac = "00:00:00:00:00:00"

// FakeMac is the Fake Mac address constant
const FakeMac = "ff:ff:ff:ff:ff:ff"

// Random ip constant
const Random = 1

// OldestReleased ip constant
const OldestReleased = 2

type DHCPPool struct {
	lock      *sync.RWMutex
	free      map[uint64]bool
	mac       map[uint64]string
	capacity  uint64
	released  map[uint64]int64
	algorithm int
	ctx       context.Context
	statsd   *statsd.Client
}

// NewDHCPPool constructor
func NewDHCPPool(context context.Context, capacity uint64, algorithm int) *DHCPPool {
	log.SetProcessName("pfdhcp")
	ctx := log.LoggerNewContext(context)
	d := &DHCPPool{
		lock:     &sync.RWMutex{},
		free:     make(map[uint64]bool),
		mac:      make(map[uint64]string),
		released:  make(map[uint64]int64),
		algorithm: algorithm,
		capacity: capacity,
		ctx:      ctx,
	}
	for i := uint64(0); i < d.capacity; i++ {
		d.free[i] = true
		d.released[i] = time.Now().UnixNano()
	}
	return d
}

// Compare what we have in the cache with what we have in the pool
func (dp *DHCPPool) GetIssues(macs []string) ([]string, map[uint64]string) {
	dp.lock.RLock()
	defer dp.lock.RUnlock()
	defer dp.timeTrack(time.Now(), "GetIssues")
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

// Reserves an IP in the pool, returns an error if the IP has already been reserved
func (dp *DHCPPool) ReserveIPIndex(index uint64, mac string) (error, string) {
	dp.lock.Lock()
	defer dp.lock.Unlock()
	defer dp.timeTrack(time.Now(), "ReserveIPIndex")
	if index >= dp.capacity {
		return errors.New("Trying to reserve an IP that is outside the capacity of this pool"), FreeMac
	}

	if _, free := dp.free[index]; free {
		delete(dp.free, index)
		dp.mac[index] = mac
		return nil, mac
	} else {
		return errors.New("IP is already reserved"), FreeMac
	}
}

// Frees an IP in the pool, returns an error if the IP is already free
func (dp *DHCPPool) FreeIPIndex(index uint64) error {
	dp.lock.Lock()
	defer dp.lock.Unlock()
	defer dp.timeTrack(time.Now(), "FreeIPIndex")
	if !dp.IndexInPool(index) {
		return errors.New("Trying to free an IP that is outside the capacity of this pool")
	}

	if _, free := dp.free[index]; free {
		return errors.New("IP is already free")
	} else {
		dp.free[index] = true
		dp.released[index] = time.Now().UnixNano()
		delete(dp.mac, index)
		return nil
	}
}

// Check if the IP is free at the index
func (dp *DHCPPool) IsFreeIPAtIndex(index uint64) bool {
	dp.lock.RLock()
	defer dp.lock.RUnlock()
	defer dp.timeTrack(time.Now(), "IsFreeIPAtIndex")
	if !dp.IndexInPool(index) {
		return false
	}

	if _, free := dp.free[index]; free {
		return true
	} else {
		return false
	}
}

// Check if the IP is free at the index
func (dp *DHCPPool) GetMACIndex(index uint64) (uint64, string, error) {
	dp.lock.RLock()
	defer dp.lock.RUnlock()
	defer dp.timeTrack(time.Now(), "GetMACIndex")
	if !dp.IndexInPool(index) {
		return index, FreeMac, errors.New("The index is not part of the pool")
	}

	if _, free := dp.free[index]; free {
		return index, FreeMac, nil
	} else {
		return index, dp.mac[index], nil
	}
}

// Returns a random free IP address, an error if the pool is full
func (dp *DHCPPool) GetFreeIPIndex(mac string) (uint64, string, error) {
	dp.lock.Lock()
	defer dp.lock.Unlock()
	defer dp.timeTrack(time.Now(), "GetFreeIPIndex")
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

// Returns whether or not a specific index is in the capacity of the pool
func (dp *DHCPPool) IndexInPool(index uint64) bool {
	defer dp.timeTrack(time.Now(), "IndexInPool")
	return index < dp.capacity
}

// Returns the amount of free IPs in the pool
func (dp *DHCPPool) FreeIPsRemaining() uint64 {
	dp.lock.RLock()
	defer dp.lock.RUnlock()
	defer dp.timeTrack(time.Now(), "FreeIPsRemaining")
	return uint64(len(dp.free))
}

// Returns the capacity of the pool
func (dp *DHCPPool) Capacity() uint64 {
	defer dp.timeTrack(time.Now(), "Capacity")
	return dp.capacity
}

func (dp *DHCPPool) timeTrack(start time.Time, name string) {

	elapsed := time.Since(start)
	log.LoggerWContext(dp.ctx).Debug(name + " took " + elapsed.String())
}
