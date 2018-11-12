package pool

import (
	"errors"
	"math/rand"
	"sync"
)

type DHCPPool struct {
	lock     *sync.Mutex
	free     map[uint64]bool
	capacity uint64
}

func NewDHCPPool(capacity uint64) *DHCPPool {
	d := &DHCPPool{
		lock:     &sync.Mutex{},
		free:     make(map[uint64]bool),
		capacity: capacity,
	}
	for i := uint64(0); i < d.capacity; i++ {
		d.free[i] = true
	}
	return d
}

// Reserves an IP in the pool, returns an error if the IP has already been reserved
func (dp *DHCPPool) ReserveIPIndex(index uint64) error {
	dp.lock.Lock()
	defer dp.lock.Unlock()

	if index >= dp.capacity {
		return errors.New("Trying to reserve an IP that is outside the capacity of this pool")
	}

	if _, free := dp.free[index]; free {
		delete(dp.free, index)
		return nil
	} else {
		return errors.New("IP is already reserved")
	}
}

// Frees an IP in the pool, returns an error if the IP is already free
func (dp *DHCPPool) FreeIPIndex(index uint64) error {
	dp.lock.Lock()
	defer dp.lock.Unlock()

	if index >= dp.capacity {
		return errors.New("Trying to free an IP that is outside the capacity of this pool")
	}

	if _, free := dp.free[index]; free {
		return errors.New("IP is already free")
	} else {
		dp.free[index] = true
		return nil
	}
}

// Returns a random free IP address, an error if the pool is full
func (dp *DHCPPool) GetFreeIPIndex() (uint64, error) {
	dp.lock.Lock()
	defer dp.lock.Unlock()

	if len(dp.free) == 0 {
		return 0, errors.New("DHCP pool is full")
	}
	index := rand.Intn(len(dp.free))

	var available uint64
	for available = range dp.free {
		if index == 0 {
			break
		}
		index--
	}

	delete(dp.free, available)

	return available, nil
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
