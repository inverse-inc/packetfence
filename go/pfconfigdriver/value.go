package pfconfigdriver

import (
	"context"
	"reflect"
	"sync/atomic"
)

type CachedValue struct {
	value atomic.Value
	oType reflect.Type
}

func NewCachedValue(oType reflect.Type) *CachedValue {
	return &CachedValue{
		oType: oType,
	}
}

func (cv *CachedValue) Value(ctx context.Context) (PfconfigObject, error) {
	old := cv.value.Load()
	if old == nil {
		obj := cv.newType()
		err := FetchDecodeSocket(ctx, obj)
		if err != nil {
			return nil, err
		}

		cv.value.Store(obj)
		return obj, nil
	}

	obj := old.(PfconfigObject)
	if IsValid(ctx, obj) {
		return obj, nil
	}

	newObj := cv.newType()
	err := FetchDecodeSocket(ctx, newObj)
	if err != nil {
		return obj, err
	}

	cv.value.Store(newObj)
	return newObj, nil
}

func (cv *CachedValue) newType() PfconfigObject {
	return reflect.New(cv.oType).Interface().(PfconfigObject)
}
