package pfconfigdriver

import (
	"context"
	"fmt"
	"sync"

	"github.com/inverse-inc/go-utils/log"
)

type CachedHash struct {
	PfconfigNS string
	Ids        PfconfigKeys
	Structs    map[string]PfconfigObject
	New        func(context.Context, string) (PfconfigObject, error)
	// mutex guards Refresh and the read accessors. Refresh both rewrites
	// cc.Ids (FetchDecodeSocket zeroes then refills it) and rewrites the
	// Structs map, so concurrent callers (e.g. one per inbound connection)
	// would otherwise observe torn reads — most visibly an empty key in
	// cc.Ids.Response.Keys, which then crashes New() with an empty id.
	mutex sync.Mutex
}

func (cc *CachedHash) Refresh(ctx context.Context) {
	cc.mutex.Lock()
	defer cc.mutex.Unlock()

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
	cc.mutex.Lock()
	defer cc.mutex.Unlock()

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
	cc.mutex.Lock()
	defer cc.mutex.Unlock()
	return append([]string(nil), cc.Ids.Keys...)
}

// GetStruct returns the instantiated object for id and whether it exists,
// taking the lock so it is safe to call concurrently with Refresh.
func (cc *CachedHash) GetStruct(ctx context.Context, id string) (PfconfigObject, bool) {
	cc.mutex.Lock()
	defer cc.mutex.Unlock()
	o, ok := cc.Structs[id]
	return o, ok
}

// SnapshotStructs returns a shallow copy of the id->object map, taken under
// the lock, so callers can iterate without racing against Refresh swapping
// the underlying map.
func (cc *CachedHash) SnapshotStructs(ctx context.Context) map[string]PfconfigObject {
	cc.mutex.Lock()
	defer cc.mutex.Unlock()
	snapshot := make(map[string]PfconfigObject, len(cc.Structs))
	for id, o := range cc.Structs {
		snapshot[id] = o
	}
	return snapshot
}
