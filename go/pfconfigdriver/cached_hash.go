package pfconfigdriver

import (
	"context"
	"fmt"

	"github.com/inverse-inc/go-utils/log"
)

type CachedHash struct {
	PfconfigNS string
	Ids        PfconfigKeys
	Structs    map[string]PfconfigObject
	New        func(context.Context, string) (PfconfigObject, error)
}

func (cc *CachedHash) Refresh(ctx context.Context) {
	cc.Ids.PfconfigNS = cc.PfconfigNS

	var reload bool

	// If ids changed, we want to reload
	if !IsValid(ctx, &cc.Ids) {
		reload = true
	}

	FetchDecodeSocketCache(ctx, &cc.Ids)

	if cc.Structs != nil {
		for _, id := range cc.Ids.Response.Keys {
			o, ok := cc.Structs[id]

			if !ok {
				log.LoggerWContext(ctx).Debug("An object was added in the hash. Will read the hash again.")
				reload = true
				break
			}

			if !IsValid(ctx, o) {
				log.LoggerWContext(ctx).Debug(fmt.Sprintf("Item %s has been detected as expired in pfconfig. Reloading.", id))
				reload = true
			}
		}
	} else {
		reload = true
	}

	if reload {
		newObjects := make(map[string]PfconfigObject)

		for _, id := range cc.Ids.Response.Keys {
			log.LoggerWContext(ctx).Debug(fmt.Sprintf("Adding object %s", id))

			o, err := cc.New(ctx, id)
			if err != nil {
				log.LoggerWContext(ctx).Error(fmt.Sprintf("Cannot instantiate object %s because of an error (%s). Ignoring it.", id, err))
			} else {
				newObjects[id] = o
			}
		}
		cc.Structs = newObjects
	}
}

func (cc *CachedHash) IsValid(ctx context.Context) bool {
	if !IsValid(ctx, &cc.Ids) {
		return false
	}

	for _, id := range cc.Ids.Response.Keys {
		o, ok := cc.Structs[id]
		if !ok {
			return false
		}

		if !IsValid(ctx, o) {
			return false
		}
	}

	return true
}

func (cc *CachedHash) Keys(ctx context.Context) []string {
	return cc.Ids.Keys
}
