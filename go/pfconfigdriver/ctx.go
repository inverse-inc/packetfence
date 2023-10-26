package pfconfigdriver

import (
	"context"
)

const pfconfigCtxKey = "pfconfigCtxKey"

// Grab a context that includes a UUID of the request for logging purposes
func NewContext(ctx context.Context) context.Context {
	store := PfconfigConfigPool.GetStore()
	return context.WithValue(ctx, pfconfigCtxKey, store)
}

func GetConfigFromContext(ctx context.Context, n string) interface{} {
	store := ctx.Value(pfconfigCtxKey).(*ConfigStore)
	if store == nil {
		return nil
	}

	return store.GetStruct(n)
}

func GetRefreshFromContext(ctx context.Context, n string) interface{} {
	store := ctx.Value(pfconfigCtxKey).(*ConfigStore)
	if store != nil {
		return nil
	}

	return store.GetRefreshable(n)
}
