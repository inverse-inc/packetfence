package pool

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"math/rand"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"gopkg.in/alexcesaro/statsd.v2"
)

// Memory struct with optimized fields
type Memory struct {
	PoolName string
	DHCPPool *DHCPPool
	SQL      *sql.DB
	// Add a free list for faster access to free IPs
	freeList []uint64
	// Add a map for quick MAC lookups
	macLookup map[string]uint64
}

// NewMemoryPool returns a new memory pool with optimized initialization
func NewMemoryPool(ctx context.Context, capacity uint64, name string, algorithm int, StatsdClient *statsd.Client, sql *sql.DB) (Backend, error) {
	pool := &Memory{
		PoolName:  name,
		SQL:       sql,
		freeList:  make([]uint64, 0, capacity),
		macLookup: make(map[string]uint64, capacity),
	}

	if err := pool.NewDHCPPool(ctx, capacity, algorithm, StatsdClient); err != nil {
		return nil, fmt.Errorf("failed to initialize DHCP pool: %w", err)
	}

	return pool, nil
}

// NewDHCPPool initializes the DHCPPool with optimized data structures
func (dp *Memory) NewDHCPPool(ctx context.Context, capacity uint64, algorithm int, StatsdClient *statsd.Client) error {
	log.SetProcessName("pfdhcp")
	loggerCtx := log.LoggerNewContext(ctx)

	d := &DHCPPool{
		lock:      &sync.RWMutex{},
		free:      make(map[uint64]bool, capacity),
		mac:       make(map[uint64]string, capacity),
		released:  make(map[uint64]int64, capacity),
		algorithm: algorithm,
		capacity:  capacity,
		ctx:       loggerCtx,
		statsd:    StatsdClient,
	}

	// Pre-allocate all IPs as free
	now := time.Now().UnixNano()
	for i := uint64(0); i < capacity; i++ {
		d.free[i] = true
		d.released[i] = now
		dp.freeList = append(dp.freeList, i)
	}

	dp.DHCPPool = d
	return nil
}

// GetIssues optimized with better data structures and algorithms
func (dp *Memory) GetIssues(macs []string) ([]string, map[uint64]string) {
	dp.DHCPPool.lock.RLock()
	defer dp.DHCPPool.lock.RUnlock()

	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "GetIssues")

	// Create a map for O(1) MAC lookups
	macSet := make(map[string]struct{}, len(macs))
	for _, mac := range macs {
		macSet[mac] = struct{}{}
	}

	inPoolNotInCache := make([]string, 0, dp.DHCPPool.capacity)
	duplicateInPool := make(map[uint64]string)

	// Track MAC occurrences in a single pass
	macCount := make(map[string][]uint64)

	for i := uint64(0); i < dp.DHCPPool.capacity; i++ {
		if dp.DHCPPool.free[i] {
			continue
		}

		mac := dp.DHCPPool.mac[i]
		if _, exists := macSet[mac]; !exists {
			inPoolNotInCache = append(inPoolNotInCache, fmt.Sprintf("%s, %d", mac, i))
		}

		macCount[mac] = append(macCount[mac], i)
	}

	// Find duplicates in a single pass
	for mac, indices := range macCount {
		if len(indices) > 1 {
			for _, idx := range indices {
				duplicateInPool[idx] = mac
			}
		}
	}

	return inPoolNotInCache, duplicateInPool
}

// ReserveIPIndex optimized with better locking and error handling
func (dp *Memory) ReserveIPIndex(index uint64, mac string) (string, error) {
	dp.DHCPPool.lock.Lock()
	defer dp.DHCPPool.lock.Unlock()

	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "ReserveIPIndex")

	if index >= dp.DHCPPool.capacity {
		return FreeMac, errors.New("index outside pool capacity")
	}

	if !dp.DHCPPool.free[index] {
		return FreeMac, errors.New("IP already reserved")
	}

	// Update all relevant data structures
	delete(dp.DHCPPool.free, index)
	dp.DHCPPool.mac[index] = mac
	dp.macLookup[mac] = index

	// Remove from free list
	for i, freeIndex := range dp.freeList {
		if freeIndex == index {
			dp.freeList = append(dp.freeList[:i], dp.freeList[i+1:]...)
			break
		}
	}

	return mac, nil
}

// FreeIPIndex optimized with better data structure management
func (dp *Memory) FreeIPIndex(index uint64) error {
	dp.DHCPPool.lock.Lock()
	defer dp.DHCPPool.lock.Unlock()

	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "FreeIPIndex")

	if !dp.IndexInPool(index) {
		return errors.New("index outside pool capacity")
	}

	if dp.DHCPPool.free[index] {
		return errors.New("IP already free")
	}

	// Update all relevant data structures
	dp.DHCPPool.free[index] = true
	dp.DHCPPool.released[index] = time.Now().UnixNano()
	mac := dp.DHCPPool.mac[index]
	delete(dp.DHCPPool.mac, index)
	delete(dp.macLookup, mac)
	dp.freeList = append(dp.freeList, index)

	return nil
}

// GetFreeIPIndex optimized with better algorithm selection
func (dp *Memory) GetFreeIPIndex(mac string) (uint64, string, error) {
	dp.DHCPPool.lock.Lock()
	defer dp.DHCPPool.lock.Unlock()

	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "GetFreeIPIndex")

	if len(dp.freeList) == 0 {
		return 0, FreeMac, errors.New("DHCP pool is full")
	}

	var available uint64

	if dp.DHCPPool.algorithm == OldestReleased {
		// Use the free list which maintains order
		available = dp.freeList[0]
		dp.freeList = dp.freeList[1:]
	} else {
		// Random selection from free list
		idx := rand.Intn(len(dp.freeList))
		available = dp.freeList[idx]
		dp.freeList = append(dp.freeList[:idx], dp.freeList[idx+1:]...)
	}

	// Update all relevant data structures
	delete(dp.DHCPPool.free, available)
	dp.DHCPPool.mac[available] = mac
	dp.macLookup[mac] = available

	return available, mac, nil
}

// IsFreeIPAtIndex optimized with direct map access
func (dp *Memory) IsFreeIPAtIndex(index uint64) bool {
	dp.DHCPPool.lock.RLock()
	defer dp.DHCPPool.lock.RUnlock()

	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "IsFreeIPAtIndex")

	return dp.IndexInPool(index) && dp.DHCPPool.free[index]
}

// GetMACIndex optimized with better error handling
func (dp *Memory) GetMACIndex(index uint64) (uint64, string, error) {
	dp.DHCPPool.lock.RLock()
	defer dp.DHCPPool.lock.RUnlock()

	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "GetMACIndex")

	if !dp.IndexInPool(index) {
		return index, FreeMac, errors.New("index not in pool")
	}

	if dp.DHCPPool.free[index] {
		return index, FreeMac, nil
	}

	return index, dp.DHCPPool.mac[index], nil
}

// FreeIPsRemaining optimized with direct length access
func (dp *Memory) FreeIPsRemaining() uint64 {
	dp.DHCPPool.lock.RLock()
	defer dp.DHCPPool.lock.RUnlock()

	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "FreeIPsRemaining")

	return uint64(len(dp.freeList))
}

// Capacity optimized with direct access
func (dp *Memory) Capacity() uint64 {
	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "Capacity")
	return dp.DHCPPool.capacity
}

// Listen always returns true for memory backend
func (dp *Memory) Listen() bool {
	return true
}

// GetDHCPPool return the DHCPPool
func (dp *Memory) GetDHCPPool() DHCPPool {
	return *dp.DHCPPool
}

// IndexInPool returns whether or not a specific index is in the capacity of the pool
func (dp *Memory) IndexInPool(index uint64) bool {
	t := dp.DHCPPool.NewTiming()
	defer dp.DHCPPool.timeTrack(t, "IndexInPool")
	return index < dp.DHCPPool.capacity
}
