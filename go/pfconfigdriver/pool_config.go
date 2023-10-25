package pfconfigdriver

import (
	"context"
	"reflect"
	"sync"
	"sync/atomic"

	clone "github.com/huandu/go-clone/generic"
	"github.com/inverse-inc/go-utils/log"
)

var PfconfigConfigPool *ConfigPool

type ConfigStore struct {
	refreshables map[string]Refresh
	structs      map[string]interface{}
}

func (cs *ConfigStore) GetStruct(n string) interface{} {
	return cs.structs[n]
}

func (cs *ConfigStore) GetRefreshable(n string) Refresh {
	return cs.refreshables[n]
}

func (cs *ConfigStore) Clone() *ConfigStore {
	c := &ConfigStore{}
	c.structs = clone.Clone(cs.structs)
	c.refreshables = clone.Clone(cs.refreshables)

	return c
}

func (cs *ConfigStore) updater() *ConfigStoreUpdater {
	return (*ConfigStoreUpdater)(cs)
}

func NewConfigStore() *ConfigStore {
	return &ConfigStore{
		structs:      make(map[string]interface{}),
		refreshables: make(map[string]Refresh),
	}
}

type ConfigStoreUpdater ConfigStore

func (cs *ConfigStoreUpdater) AddRefreshable(n string, i Refresh) {
	cs.refreshables[n] = i
}

func (cs *ConfigStoreUpdater) AddStruct(n string, i interface{}) {
	cs.structs[n] = i
}

func (cs *ConfigStoreUpdater) Refresh(ctx context.Context) {
	for _, s := range cs.structs {
		refreshStruct(ctx, s)
	}
}

func (cs *ConfigStoreUpdater) IsValid(ctx context.Context) bool {
	for _, s := range cs.structs {
		if !isStructValid(ctx, s) {
			return false
		}
	}

	for _, r := range cs.refreshables {
		if !r.IsValid() {
			return false
		}
	}

	return true
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
	Refresh(ctx context.Context) Refresh
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
	cs := p.GetStore().Clone()
	f(ctx, cs.updater())
	p.store.Store(cs)
}

func updateRefresh(ctx context.Context, r Refresh) Refresh {
	if !r.IsValid() {
		r = r.Refresh(ctx)
	}

	return r
}

// Add a refreshable resource to the pool
// Requires the RW lock and will not timeout like Refresh does
func (p *ConfigPool) AddRefreshable(ctx context.Context, n string, r Refresh) {
	p.Update(
		ctx,
		func(ctx context.Context, u *ConfigStoreUpdater) {
			u.AddRefreshable(n, updateRefresh(ctx, r))
		},
	)
}

// Add a struct to the pool
// Requires the RW lock and will not timeout like Refresh does
func (p *ConfigPool) AddStruct(ctx context.Context, n string, s interface{}) {
	p.Update(
		ctx,
		func(ctx context.Context, u *ConfigStoreUpdater) {
			refreshStruct(ctx, s)
			u.AddStruct(n, s)
		},
	)
}

// Refresh all the refreshables of the pool
func refreshRefreshables(ctx context.Context, refreshables map[string]Refresh) {
	for _, r := range refreshables {
		r.Refresh(ctx)
	}
}

// Refresh a struct
// If this struct is a PfconfigObject, it will be sent directly to FetchDecodeSocketCache
// Otherwise, the struct fields and sub-fields will be analyzed to find all the PfconfigObjects and these will be sent to FetchDecodeSocketCache
func refreshStruct(ctx context.Context, s interface{}) {
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
				refreshStruct(ctx, field.Interface())
			}
		}
	}
}

// Refresh a struct
// If this struct is a PfconfigObject, it will be sent directly to FetchDecodeSocketCache
// Otherwise, the struct fields and sub-fields will be analyzed to find all the PfconfigObjects and these will be sent to FetchDecodeSocketCache
func isStructValid(ctx context.Context, s interface{}) bool {
	v := reflect.ValueOf(s)
	for v.Kind() == reflect.Ptr || v.Kind() == reflect.Interface {
		v = v.Elem()
	}

	// Check if s itself is a PfconfigObject, otherwise, we cycle though its fields and process them
	if o, ok := v.Addr().Interface().(PfconfigObject); ok {
		return IsValid(ctx, o)
	}

	for i := 0; i < v.NumField(); i++ {
		field := v.Field(i).Addr()
		if !isStructValid(ctx, field.Interface()) {
			return false
		}
	}

	return true
}

func cloneStruct(s interface{}) interface{} {
	clone := reflect.New(reflect.TypeOf(s).Elem())
	val := reflect.ValueOf(s).Elem()
	nVal := clone.Elem()
	for i := 0; i < val.NumField(); i++ {
		nvField := nVal.Field(i)
		nvField.Set(val.Field(i))
	}

	return clone.Interface()

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
	log.LoggerWContext(ctx).Debug("Refreshing pfconfig pool")
	cs := p.GetStore().Clone()
	updater := cs.updater()
	updater.Refresh(ctx)
	p.store.Store(cs)
	log.LoggerWContext(ctx).Debug("Finished refresh of pfconfig pool")
	return true
}
