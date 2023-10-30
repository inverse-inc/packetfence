package pfconfigdriver

import (
	"context"
	"sync"
	"sync/atomic"

	"github.com/inverse-inc/go-utils/log"
)

var PfConfigStorePool *ConfigStorePool

func UpdateConfigStore(ctx context.Context, f func(context.Context, *ConfigStoreUpdater)) {
	PfConfigStorePool.Update(ctx, f)
}

func AddStruct(ctx context.Context, n string, i interface{}) {
	PfConfigStorePool.AddStruct(ctx, n, i)
}

func AddRefreshable(ctx context.Context, n string, i Refresh) {
	PfConfigStorePool.AddRefreshable(ctx, n, i)
}

func GetStruct(ctx context.Context, n string) interface{} {
	i := GetConfigFromContext(ctx, n)
	if i != nil {
		return i
	}

	return PfConfigStorePool.GetStore().GetStruct(n)
}

func GetRefresh(ctx context.Context, n string) interface{} {
	i := GetRefreshFromContext(ctx, n)
	if i != nil {
		return i
	}

	return PfConfigStorePool.GetStore().GetRefreshable(n)
}

// A pool to load resources in and refresh them periodically
// The structs will be analyzed and all the PfconfigObject will be sent to FetchDecodeSocketCache.
// If a struct isn't a PfconfigObject, all its fields will be analyzed to find the PfconfigObjects it contains
// All the refreshables will have their Refresh() function called on every tick
type ConfigStorePool struct {
	store *atomic.Value
	lock  *sync.Mutex
}

// Init the default global pool when importing this package
func init() {
	PfConfigStorePool = NewConfigPool()
}

// Interface that should be implemented by resources that should be added to pool.refreshables
type Refresh interface {
	IsValid(ctx context.Context) bool
	Refresh(ctx context.Context)
}

// Create a new Pool with a 1 second refresh timeout and initialize the lock
func NewConfigPool() *ConfigStorePool {
	p := &ConfigStorePool{
		lock:  &sync.Mutex{},
		store: &atomic.Value{},
	}

	p.store.Store(NewConfigStore())
	return p
}

func (p *ConfigStorePool) GetStore() *ConfigStore {
	return p.store.Load().(*ConfigStore)
}

func (p *ConfigStorePool) Update(ctx context.Context, f func(context.Context, *ConfigStoreUpdater)) {
	p.lock.Lock()
	defer p.lock.Unlock()
	cs := p.GetStore().Clone()
	f(ctx, cs.updater())
	p.store.Store(cs)
}

// Add a refreshable resource to the pool
// Requires the RW lock and will not timeout like Refresh does
func (p *ConfigStorePool) AddRefreshable(ctx context.Context, n string, r Refresh) {
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
func (p *ConfigStorePool) AddStruct(ctx context.Context, n string, s interface{}) {
	p.Update(
		ctx,
		func(ctx context.Context, u *ConfigStoreUpdater) {
			u.AddStruct(ctx, n, s)
		},
	)
}

// Refresh all the structs and resources of the pool using the RW lock
// An attempt to get the RW lock will be done for up to RefreshLockTimeout
func (p *ConfigStorePool) Refresh(ctx context.Context) bool {
	p.lock.Lock()
	defer p.lock.Unlock()
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
