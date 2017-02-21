package pfconfigdriver

import (
	"context"
	"reflect"
)

var PfconfigPool Pool

func init() {
	PfconfigPool = Pool{}
}

type Refreshable interface {
	Refresh(ctx context.Context)
}

type Pool struct {
	refreshables []Refreshable
	structs      []interface{}
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

func (p *Pool) Refresh(ctx context.Context) {
	p.refreshStructs(ctx)
	p.refreshRefreshables(ctx)
}

func (p *Pool) refreshStruct(ctx context.Context, s interface{}) {
	v := reflect.ValueOf(s)
	for v.Kind() == reflect.Ptr || v.Kind() == reflect.Interface {
		v = v.Elem()
	}

	for i := 0; i < v.NumField(); i++ {
		field := v.Field(i).Addr()
		if o, ok := field.Interface().(PfconfigObject); ok {
			FetchDecodeSocketCache(ctx, o)
		} else {
			p.refreshStruct(ctx, field.Interface())
		}
	}
}

func (p *Pool) refreshStructs(ctx context.Context) {
	for _, o := range p.structs {
		p.refreshStruct(ctx, o)
	}
}
