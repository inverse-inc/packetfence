package pfconfigdriver

import (
	"context"
	"fmt"
	"reflect"
	"sync"
	"time"

	"github.com/inverse-inc/packetfence/go/log"
)

var PfconfigPool Pool

// A pool to load resources in and refresh them periodically
// The structs will be analyzed and all the PfconfigObject will be sent to FetchDecodeSocketCache.
// If a struct isn't a PfconfigObject, all its fields will be analyzed to find the PfconfigObjects it contains
// All the refreshables will have their Refresh() function called on every tick
type Pool struct {
	refreshables []Refreshable
	structs      map[string]interface{}
	lock         *sync.RWMutex
	// The time to wait for the lock for the refresh in ms
	// Defaults to 1 seconds
	RefreshLockTimeout time.Duration
}

// Init the default global pool when importing this package
func init() {
	PfconfigPool = NewPool()
}

// Interface that should be implemented by resources that should be added to pool.refreshables
type Refreshable interface {
	Refresh(ctx context.Context)
}

// Create a new Pool with a 1 second refresh timeout and initialize the lock
func NewPool() Pool {
	p := Pool{}
	p.lock = &sync.RWMutex{}
	p.RefreshLockTimeout = time.Duration(100 * time.Millisecond)
	p.structs = make(map[string]interface{})
	return p
}

// Acquire a read lock on the pool
// All the goroutines that use resources from the pool should call this and release it when they are done
// Long running processes should aim to retain this lock for the smallest time possible since Refresh will need a RW lock to refresh the resources
// This lock can be acquired multiple times given its a read lock
func (p *Pool) ReadLock(ctx context.Context) {
	p.lock.RLock()
}

// Unlock the read lock
func (p *Pool) ReadUnlock(ctx context.Context) {
	p.lock.RUnlock()
}

// Add a refreshable resource to the pool
// Requires the RW lock and will not timeout like Refresh does
func (p *Pool) AddRefreshable(ctx context.Context, r Refreshable) {
	p.lock.Lock()
	defer p.lock.Unlock()

	p.refreshables = append(p.refreshables, r)
	r.Refresh(ctx)
}

// Add a struct to the pool
// Requires the RW lock and will not timeout like Refresh does
func (p *Pool) AddStruct(ctx context.Context, s interface{}) {
	p.lock.Lock()
	defer p.lock.Unlock()

	addr := fmt.Sprintf("%p", s)
	log.LoggerWContext(ctx).Debug("Adding struct with address " + addr + " to the pool")

	p.structs[addr] = s
	p.refreshStruct(ctx, s)
}

// Refresh all the refreshables of the pool
func (p *Pool) refreshRefreshables(ctx context.Context) {
	for _, r := range p.refreshables {
		r.Refresh(ctx)
	}
}

// Refresh a struct
// If this struct is a PfconfigObject, it will be sent directly to FetchDecodeSocketCache
// Otherwise, the struct fields and sub-fields will be analyzed to find all the PfconfigObjects and these will be sent to FetchDecodeSocketCache
func (p *Pool) refreshStruct(ctx context.Context, s interface{}) {
	v := reflect.ValueOf(s)
	for v.Kind() == reflect.Ptr || v.Kind() == reflect.Interface {
		v = v.Elem()
	}

	// Check if s itself is a PfconfigObject, otherwise, we cycle though its fields and process them
	if o, ok := v.Addr().Interface().(PfconfigObject); ok {
		FetchDecodeSocketCache(ctx, o)
	} else {
		for i := 0; i < v.NumField(); i++ {
			field := v.Field(i).Addr()
			if o, ok := field.Interface().(PfconfigObject); ok {
				FetchDecodeSocketCache(ctx, o)
			} else {
				p.refreshStruct(ctx, field.Interface())
			}
		}
	}
}

// Refresh all the structs of the pool
func (p *Pool) refreshStructs(ctx context.Context) {
	for _, o := range p.structs {
		p.refreshStruct(ctx, o)
	}
}

// Attempts to obtain a RW lock with the timeout set in RefreshLockTimeout
// Even if the timeout gets reached, the lock will still be acquired when available but it will be immediately released
// This is done by sending a message twice in the timeoutChan, one will be caught by the main waiting goroutine, the other one by the lock-waiting goroutine
// When the lock-waiting goroutine is able to get something out of the timeoutChan channel, it knows it must release the lock immediately
func (p *Pool) acquireWriteLock(ctx context.Context) bool {
	// timeoutChan has a capacity of 2 because it signals the timeout to the locking goroutine and the lock-waiting goroutine
	timeoutChan := make(chan int, 2)
	go func() {
		time.Sleep(p.RefreshLockTimeout)
		timeoutChan <- 1
	}()

	lockChan := make(chan int, 1)
	go func() {
		p.lock.Lock()
		lockChan <- 1
	}()

	select {
	case <-lockChan:
		log.LoggerWContext(ctx).Debug("Acquired lock for pfconfig pool")
		return true
	case <-timeoutChan:
		log.LoggerWContext(ctx).Error("Couldn't acquire lock for pfconfig pool")
		p.lock.Unlock()
		return false
	}

}

// Refresh all the structs and resources of the pool using the RW lock
// An attempt to get the RW lock will be done for up to RefreshLockTimeout
func (p *Pool) Refresh(ctx context.Context) bool {
	log.LoggerWContext(ctx).Debug("Refreshing pfconfig pool")

	if !p.acquireWriteLock(ctx) {
		return false
	}
	defer p.lock.Unlock()

	p.refreshStructs(ctx)
	p.refreshRefreshables(ctx)
	log.LoggerWContext(ctx).Debug("Finished refresh of pfconfig pool")
	return true
}
