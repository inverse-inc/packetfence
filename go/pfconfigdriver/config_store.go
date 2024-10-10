package pfconfigdriver

import (
	"context"
	"reflect"

	clone "github.com/huandu/go-clone/generic"
)

var j reflect.Type = reflect.TypeOf("")

type ConfigStoreType struct {
	refreshables map[string]Refresh
	structs      map[reflect.Type]interface{}
}

func (s *ConfigStoreType) GetStruct(t reflect.Type) interface{} {
	return s.structs[t]
}

func (s *ConfigStoreType) SetStruct(i interface{}) {
	s.structs[reflect.TypeOf(i)] = i
}

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
	c2 := &ConfigStore{}
	c2.structs = clone.Clone(cs.structs)
	c2.refreshables = make(map[string]Refresh)
	for k, r := range cs.refreshables {
		c2.refreshables[k] = r.Clone()
	}

	return c2
}

func (cs *ConfigStore) updater() *ConfigStoreUpdater {
	return (*ConfigStoreUpdater)(cs)
}

func (cs *ConfigStore) IsValid(ctx context.Context) bool {
	for _, s := range cs.structs {
		if !isStructValid(ctx, s) {
			return false
		}
	}

	for _, r := range cs.refreshables {
		if !r.IsValid(ctx) {
			return false
		}
	}

	return true
}

func NewConfigStore() *ConfigStore {
	return &ConfigStore{
		structs:      make(map[string]interface{}),
		refreshables: make(map[string]Refresh),
	}
}

type ConfigStoreUpdater ConfigStore

func (cs *ConfigStoreUpdater) AddRefreshable(ctx context.Context, n string, i Refresh) {
	cs.refreshables[n] = i
}

func (cs *ConfigStoreUpdater) AddStruct(ctx context.Context, n string, i interface{}) {
	refreshStruct(ctx, i)
	cs.structs[n] = i
}

func ConfigStoreUpdaterAddType[T any](ctx context.Context, cs *ConfigStoreUpdater) {
	var z T
	var valType = reflect.TypeOf(z)
	cs.AddStruct(ctx, valType.String(), &z)
}

func (cs *ConfigStoreUpdater) Refresh(ctx context.Context) {
	for _, s := range cs.structs {
		refreshStruct(ctx, s)
	}

	for _, s := range cs.refreshables {
		s.Refresh(ctx)
	}
}

// Check if items in the store is still valid
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
		return
	}

	for i := 0; i < v.NumField(); i++ {
		field := v.Field(i).Addr()
		if o, ok := field.Interface().(PfconfigObject); ok {
			FetchDecodeSocketCache(ctx, o)
		} else {
			refreshStruct(ctx, field.Interface())
		}
	}
}
