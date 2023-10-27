package pfconfigdriver

import (
	"context"
	"sync"
	"sync/atomic"

	"github.com/inverse-inc/go-utils/log"
)

var PfconfigConfigPool *ConfigPool

func UpdateConfigStore(ctx context.Context, f func(context.Context, *ConfigStoreUpdater)) {
	PfconfigConfigPool.Update(ctx, f)
}

func AddStruct(ctx context.Context, n string, i interface{}) {
	PfconfigConfigPool.AddStruct(ctx, n, i)
}

func GetStruct(ctx context.Context, n string) interface{} {
	i := GetConfigFromContext(ctx, n)
	if i != nil {
		return i
	}

	return PfconfigConfigPool.GetStore().GetStruct(n)
}

// A pool to load resources in and refresh them periodically
// The structs will be analyzed and all the PfconfigObject will be sent to FetchDecodeSocketCache.
// If a struct isn't a PfconfigObject, all its fields will be analyzed to find the PfconfigObjects it contains
// All the refreshables will have their Refresh() function called on every tick
type ConfigPool struct {
	store *atomic.Value
	lock  *sync.Mutex
}

// Init the default global pool when importing this package
func init() {
	PfconfigConfigPool = NewConfigPool()
}

// Interface that should be implemented by resources that should be added to pool.refreshables
type Refresh interface {
	IsValid() bool
	Refresh(ctx context.Context)
}

// Create a new Pool with a 1 second refresh timeout and initialize the lock
func NewConfigPool() *ConfigPool {
	p := &ConfigPool{
		lock:  &sync.Mutex{},
		store: &atomic.Value{},
	}

	p.store.Store(NewConfigStore())
	return p
}

func (p *ConfigPool) GetStore() *ConfigStore {
	return p.store.Load().(*ConfigStore)
}

func (p *ConfigPool) Update(ctx context.Context, f func(context.Context, *ConfigStoreUpdater)) {
	p.lock.Lock()
	defer p.lock.Unlock()
	cs := p.GetStore().Clone()
	f(ctx, cs.updater())
	p.store.Store(cs)
}

// Add a refreshable resource to the pool
// Requires the RW lock and will not timeout like Refresh does
func (p *ConfigPool) AddRefreshable(ctx context.Context, n string, r Refresh) {
	p.Update(
		ctx,
		func(ctx context.Context, u *ConfigStoreUpdater) {
			r.Refresh(ctx)
			u.AddRefreshable(ctx, n, r)
		},
	)
}

// Add a struct to the pool
// Requires the RW lock and will not timeout like Refresh does
func (p *ConfigPool) AddStruct(ctx context.Context, n string, s interface{}) {
	p.Update(
		ctx,
		func(ctx context.Context, u *ConfigStoreUpdater) {
			u.AddStruct(ctx, n, s)
		},
	)
}

// Refresh all the refreshables of the pool
func refreshRefreshables(ctx context.Context, refreshables map[string]Refresh) {
	for _, r := range refreshables {
		r.Refresh(ctx)
	}
}

// Refresh all the structs of the pool
func (p *ConfigPool) refreshStructs(ctx context.Context, structs map[string]interface{}) {
	for _, o := range structs {
		refreshStruct(ctx, o)
	}
}

// Refresh all the structs and resources of the pool using the RW lock
// An attempt to get the RW lock will be done for up to RefreshLockTimeout
func (p *ConfigPool) Refresh(ctx context.Context) bool {
	cs := p.GetStore()
	if cs.IsValid(ctx) {
		return false
	}

	cs = cs.Clone()
	log.LoggerWContext(ctx).Debug("Refreshing pfconfig config pool")
	updater := cs.updater()
	updater.Refresh(ctx)
	p.store.Store(cs)
	log.LoggerWContext(ctx).Debug("Finished refresh of pfconfig config pool")
	return true
}
