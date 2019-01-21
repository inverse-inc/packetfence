package pool

import (
	"errors"
	"math/rand"
	"strconv"
	"sort"
	"sync"
	"time"
)

const FreeMac = "00:00:00:00:00:00"
const FakeMac = "ff:ff:ff:ff:ff:ff"

type DHCPPool struct {
	lock      *sync.Mutex
	free      map[uint64]bool
	mac       map[uint64]string
	capacity  uint64
	released  map[uint64]int64
	algorithm int
}

func NewDHCPPool(capacity uint64, algorithm int) *DHCPPool {
	d := &DHCPPool{
		lock:      &sync.Mutex{},
		free:      make(map[uint64]bool),
		mac:       make(map[uint64]string),
		capacity:  capacity,
		released:  make(map[uint64]int64),
		algorithm: algorithm,
	}
	for i := uint64(0); i < d.capacity; i++ {
		d.free[i] = true
		d.released[i] = time.Now().UnixNano()
	}
	return d
}

// Compare what we have in the cache with what we have in the pool
func (dp *DHCPPool) GetIssues(macs []string) ([]string, map[uint64]string) {
	dp.lock.Lock()
	defer dp.lock.Unlock()
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
	dp.lock.Lock()
	defer dp.lock.Unlock()

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
	dp.lock.Lock()
	defer dp.lock.Unlock()

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

	if len(dp.free) == 0 {
		return 0, FreeMac, errors.New("DHCP pool is full")
	}

	var available uint64

	if dp.algorithm == 2 {

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
	return index < dp.capacity
}

// Returns the amount of free IPs in the pool
func (dp *DHCPPool) FreeIPsRemaining() uint64 {
	dp.lock.Lock()
	defer dp.lock.Unlock()
	return uint64(len(dp.free))
}

// Returns the capacity of the pool
func (dp *DHCPPool) Capacity() uint64 {
	return dp.capacity
}
