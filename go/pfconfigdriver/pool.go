package pfconfigdriver

import (
	"context"
	"fmt"
	"reflect"
	"time"

	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/timedlock"
)

var PfconfigPool Pool

// A pool to load resources in and refresh them periodically
// The structs will be analyzed and all the PfconfigObject will be sent to FetchDecodeSocketCache.
// If a struct isn't a PfconfigObject, all its fields will be analyzed to find the PfconfigObjects it contains
// All the refreshables will have their Refresh() function called on every tick
type Pool struct {
	refreshables []Refreshable
	structs      map[string]interface{}
	lock         *timedlock.RWLock
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
	p.lock = timedlock.NewRWLock()
	p.lock.Timeout = 1 * time.Second
	p.lock.RTimeout = 3 * time.Second
	p.lock.PrintErrors = false
	p.lock.Panic = false
	p.structs = make(map[string]interface{})
	return p
}

// Acquire a read lock on the pool
// All the goroutines that use resources from the pool should call this and release it when they are done
// Long running processes should aim to retain this lock for the smallest time possible since Refresh will need a RW lock to refresh the resources
// This lock can be acquired multiple times given its a read lock
func (p *Pool) ReadLock(ctx context.Context) (uint64, error) {
	return p.lock.RLock()
}

// Unlock the read lock
func (p *Pool) ReadUnlock(ctx context.Context, id uint64) {
	p.lock.RUnlock(id)
}

// Add a refreshable resource to the pool
// Requires the RW lock and will not timeout like Refresh does
func (p *Pool) AddRefreshable(ctx context.Context, r Refreshable) {
	id, err := p.lock.Lock()
	if err == nil {
		defer p.lock.Unlock(id)
		p.refreshables = append(p.refreshables, r)
		r.Refresh(ctx)
	}
}

// Add a struct to the pool
// Requires the RW lock and will not timeout like Refresh does
func (p *Pool) AddStruct(ctx context.Context, s interface{}) {
	id, err := p.lock.Lock()
	if err == nil {
		defer p.lock.Unlock(id)

		addr := fmt.Sprintf("%p", s)
		log.LoggerWContext(ctx).Debug("Adding struct with address " + addr + " to the pool")

		p.structs[addr] = s
		p.refreshStruct(ctx, s)
	}
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
func (p *Pool) acquireWriteLock(ctx context.Context) (bool, uint64) {
	defer func() {
		if r := recover(); r != nil {
			log.LoggerWContext(ctx).Warn("Couldn't acquire lock for pfconfig pool")
		}
	}()

	id, err := p.lock.Lock()
	if err != nil {
		panic("Couldn't acquire lock for pfconfig pool")
	}

	log.LoggerWContext(ctx).Debug("Acquired lock for pfconfig pool")
	return err == nil, id
}

// Refresh all the structs and resources of the pool using the RW lock
// An attempt to get the RW lock will be done for up to RefreshLockTimeout
func (p *Pool) Refresh(ctx context.Context) bool {
	log.LoggerWContext(ctx).Debug("Refreshing pfconfig pool")

	var locked bool
	var id uint64
	if locked, id = p.acquireWriteLock(ctx); !locked {
		return false
	}
	log.LoggerWContext(ctx).Debug("Refresh got lock ID", id)
	defer func(ctx context.Context) {
		log.LoggerWContext(ctx).Debug("Refresh is releasing lock ID", id)
		p.lock.Unlock(id)
	}(ctx)

	p.refreshStructs(ctx)
	p.refreshRefreshables(ctx)
	log.LoggerWContext(ctx).Debug("Finished refresh of pfconfig pool")
	return true
}
