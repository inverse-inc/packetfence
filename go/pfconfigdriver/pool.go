package pfconfigdriver

import (
	"context"
	"github.com/fingerbank/processor/log"
	"reflect"
	"sync"
	"time"
)

var PfconfigPool Pool

func init() {
	PfconfigPool = NewPool()
}

type Refreshable interface {
	Refresh(ctx context.Context)
}

func NewPool() Pool {
	p := Pool{}
	p.lock = &sync.RWMutex{}
	p.RefreshLockTimeout = time.Duration(10 * time.Second)
	return p
}

type Pool struct {
	refreshables []Refreshable
	structs      []interface{}
	lock         *sync.RWMutex
	// The time to wait for the lock for the refresh in ms
	// Defaults to 10 seconds
	RefreshLockTimeout time.Duration
}

func (p *Pool) ReadLock(ctx context.Context) {
	p.lock.RLock()
}

func (p *Pool) ReadUnlock(ctx context.Context) {
	p.lock.RUnlock()
}

func (p *Pool) AddRefreshable(ctx context.Context, r Refreshable) {
	p.refreshables = append(p.refreshables, r)
	r.Refresh(ctx)
}

func (p *Pool) AddStruct(ctx context.Context, s interface{}) {
	p.structs = append(p.structs, s)
	p.refreshStruct(ctx, s)
}

func (p *Pool) refreshRefreshables(ctx context.Context) {
	for _, r := range p.refreshables {
		r.Refresh(ctx)
	}
}

// Attempts to obtain a RW lock with the timeout set in RefreshLockTimeout
func (p *Pool) acquireWriteLock(ctx context.Context) {
	timeoutChan := make(chan int, 1)
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
		log.LoggerWContext(ctx).Debug("Acquired lock for pfconfig pool refresh")
		return
	case <-timeoutChan:
		log.LoggerWContext(ctx).Error("Couldn't acquire lock for pfconfig pool refresh")
	}

}

func (p *Pool) Refresh(ctx context.Context) {
	log.LoggerWContext(ctx).Debug("Refreshing pfconfig pool")

	p.acquireWriteLock(ctx)
	defer p.lock.Unlock()

	p.refreshStructs(ctx)
	p.refreshRefreshables(ctx)
}

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

func (p *Pool) refreshStructs(ctx context.Context) {
	for _, o := range p.structs {
		p.refreshStruct(ctx, o)
	}
}
