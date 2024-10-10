package pfconfigdriver

import (
	"context"
)

const pfconfigCtxKey = "pfconfigCtxKey"

// Grab a context that includes a UUID of the request for logging purposes
func NewContext(ctx context.Context) context.Context {
	store := PfConfigStorePool.GetStore()
	return context.WithValue(ctx, pfconfigCtxKey, store)
}

func GetConfigFromContext(ctx context.Context, n string) interface{} {
	store, ok := ctx.Value(pfconfigCtxKey).(*ConfigStore)
	if !ok || store == nil {
		return nil
	}

	return store.GetStruct(n)
}

func GetRefreshFromContext(ctx context.Context, n string) interface{} {
	store, ok := ctx.Value(pfconfigCtxKey).(*ConfigStore)
	if !ok || store == nil {
		return nil
	}

	return store.GetRefreshable(n)
}
