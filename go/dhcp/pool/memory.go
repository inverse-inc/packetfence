package pool

import (
	"context"
	"database/sql"
	"errors"
	"math/rand"
	"sort"
	"strconv"
	"sync"
	"time"

	"github.com/inverse-inc/packetfence/go/log"
	"gopkg.in/alexcesaro/statsd.v2"
)

// Memory struct
type Memory struct {
	PoolName string
	DHCPPool *DHCPPool
	SQL      *sql.DB
}

// NewMemoryPool return a new memory pool
func NewMemoryPool(context context.Context, capacity uint64, name string, algorithm int, StatsdClient *statsd.Client, sql *sql.DB) (Backend, error) {
	Pool := &Memory{}
	Pool.PoolName = name
	Pool.NewDHCPPool(context, capacity, algorithm, StatsdClient)

	return Pool, nil
}

// NewDHCPPool initialize the DHCPPool
func (dp *Memory) NewDHCPPool(context context.Context, capacity uint64, algorithm int, StatsdClient *statsd.Client) {
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
	dp.DHCPPool = d
}

// GetDHCPPool return the DHCPPool
func (dp *Memory) GetDHCPPool() DHCPPool {
	return *dp.DHCPPool
}

// GetIssues Compare what we have in the cache with what we have in the pool
func (dp *Memory) GetIssues(macs []string) ([]string, map[uint64]string) {
	dp.DHCPPool.lock.RLock()
	defer dp.DHCPPool.lock.RUnlock()
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "GetIssues")
	var found bool
	found = false
	var inPoolNotInCache []string
	var duplicateInPool map[uint64]string
	duplicateInPool = make(map[uint64]string)

	var count int
	var saveindex uint64
	for i := uint64(0); i < dp.DHCPPool.capacity; i++ {
		if dp.DHCPPool.free[i] {
			continue
		}
		for _, mac := range macs {
			if dp.DHCPPool.mac[i] == mac {
				found = true
			}
		}
		if !found {
			inPoolNotInCache = append(inPoolNotInCache, dp.DHCPPool.mac[i]+", "+strconv.Itoa(int(i)))
		}
	}
	for _, mac := range macs {
		count = 0
		saveindex = 0

		for i := uint64(0); i < dp.DHCPPool.capacity; i++ {
			if dp.DHCPPool.free[i] {
				continue
			}
			if dp.DHCPPool.mac[i] == mac {
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

// ReserveIPIndex reserves an IP in the pool, returns an error if the IP has already been reserved
func (dp *Memory) ReserveIPIndex(index uint64, mac string) (string, error) {
	dp.DHCPPool.lock.Lock()
	defer dp.DHCPPool.lock.Unlock()
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "ReserveIPIndex")

	if index >= dp.DHCPPool.capacity {
		return FreeMac, errors.New("Trying to reserve an IP that is outside the capacity of this pool")
	}

	if _, free := dp.DHCPPool.free[index]; free {
		delete(dp.DHCPPool.free, index)
		dp.DHCPPool.mac[index] = mac
		return mac, nil
	}
	return FreeMac, errors.New("IP is already reserved")
}

// FreeIPIndex frees an IP in the pool, returns an error if the IP is already free
func (dp *Memory) FreeIPIndex(index uint64) error {
	dp.DHCPPool.lock.Lock()
	defer dp.DHCPPool.lock.Unlock()
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "FreeIPIndex")
	if !dp.IndexInPool(index) {
		return errors.New("Trying to free an IP that is outside the capacity of this pool")
	}

	if _, free := dp.DHCPPool.free[index]; free {
		return errors.New("IP is already free")
	}
	dp.DHCPPool.free[index] = true
	dp.DHCPPool.released[index] = time.Now().UnixNano()
	delete(dp.DHCPPool.mac, index)
	return nil
}

// IsFreeIPAtIndex check if the IP is free at the index
func (dp *Memory) IsFreeIPAtIndex(index uint64) bool {
	dp.DHCPPool.lock.RLock()
	defer dp.DHCPPool.lock.RUnlock()
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "IsFreeIPAtIndex")
	if !dp.IndexInPool(index) {
		return false
	}

	if _, free := dp.DHCPPool.free[index]; free {
		return true
	}
	return false
}

// GetMACIndex check if the IP is free at the index
func (dp *Memory) GetMACIndex(index uint64) (uint64, string, error) {
	dp.DHCPPool.lock.RLock()
	defer dp.DHCPPool.lock.RUnlock()
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "GetMACIndex")
	if !dp.IndexInPool(index) {
		return index, FreeMac, errors.New("The index is not part of the pool")
	}

	if _, free := dp.DHCPPool.free[index]; free {
		return index, FreeMac, nil
	}
	return index, dp.DHCPPool.mac[index], nil
}

// GetFreeIPIndex returns a free IP address, an error if the pool is full
func (dp *Memory) GetFreeIPIndex(mac string) (uint64, string, error) {
	dp.DHCPPool.lock.Lock()
	defer dp.DHCPPool.lock.Unlock()
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "GetFreeIPIndex")

	if len(dp.DHCPPool.free) == 0 {
		return 0, FreeMac, errors.New("DHCP pool is full")
	}

	var available uint64

	if dp.DHCPPool.algorithm == OldestReleased {
		type kv struct {
			Key   uint64
			Value int64
		}

		var ss []kv
		for k, v := range dp.DHCPPool.released {
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
		index := rand.Intn(len(dp.DHCPPool.free))
		for available = range dp.DHCPPool.free {
			if index == 0 {
				break
			}
			index--

		}
	}

	delete(dp.DHCPPool.free, available)
	dp.DHCPPool.mac[available] = mac

	return available, mac, nil
}

// IndexInPool returns whether or not a specific index is in the capacity of the pool
func (dp *Memory) IndexInPool(index uint64) bool {
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "IndexInPool")
	return index < dp.DHCPPool.capacity
}

// FreeIPsRemaining returns the amount of free IPs in the pool
func (dp *Memory) FreeIPsRemaining() uint64 {
	dp.DHCPPool.lock.RLock()
	defer dp.DHCPPool.lock.RUnlock()
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "FreeIPsRemaining")
	return uint64(len(dp.DHCPPool.free))
}

// Capacity returns the capacity of the pool
func (dp *Memory) Capacity() uint64 {
	t := dp.DHCPPool.statsd.NewTiming()
	defer dp.timeTrack(t, "Capacity")
	return dp.DHCPPool.capacity
}

// Listen can act even if the VIP is not here
func (dp *Memory) Listen() bool {
	return false
}

// Track timing for each function
func (dp *Memory) timeTrack(t statsd.Timing, name string) {
	t.Send("pfdhcp." + name)
}
