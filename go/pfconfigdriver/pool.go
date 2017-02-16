package pfconfigdriver

import (
	"context"
	//"github.com/davecgh/go-spew/spew"
	"fmt"
	"github.com/fingerbank/processor/log"
	"os"
	"reflect"
	"time"
)

var GlobalPfconfigResourcePool *ResourcePool

func init() {
	GlobalPfconfigResourcePool = NewResourcePool(context.Background())
}

type Resource struct {
	namespace  string
	structType reflect.Type
	loadedAt   time.Time
}

func (r *Resource) controlFile() string {
	return "/usr/local/pf/var/control/" + r.namespace + "-control"
}

func (r *Resource) IsValid(ctx context.Context) bool {
	ctx = log.AddToLogContext(ctx, "PfconfigObject", r.structType.String())
	stat, err := os.Stat(r.controlFile())

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Cannot stat %s. Will consider resource as invalid"))
		return false
	} else {
		controlTime := stat.ModTime()
		if r.loadedAt.Before(controlTime) {
			log.LoggerWContext(ctx).Debug("Resource is not valid anymore. Will reload it.")
			return false
		} else {
			return true
		}
	}
}

type ResourcePool struct {
	//Map of loaded resource by type name
	loadedResources map[string]Resource
}

func NewResourcePool(ctx context.Context) *ResourcePool {
	return &ResourcePool{
		loadedResources: make(map[string]Resource),
	}
}

func (rp *ResourcePool) ResourceIsValid(ctx context.Context, o PfconfigObject) bool {
	res, ok := rp.FindResource(ctx, o)
	if ok {
		return res.IsValid(ctx)
	} else {
		return false
	}
}

func (rp *ResourcePool) FindResource(ctx context.Context, o PfconfigObject) (Resource, bool) {
	structTypeStr := rp.getStructType(ctx, o, reflect.Value{}).String()
	res, ok := rp.loadedResources[structTypeStr]
	return res, ok
}

func (rp *ResourcePool) getStructType(ctx context.Context, o PfconfigObject, reflectInfo reflect.Value) reflect.Type {
	if reflectInfo.IsValid() {
		return reflectInfo.Type()
	} else {
		return reflect.TypeOf(o).Elem()
	}
}

func (rp *ResourcePool) getNamespace(ctx context.Context, o PfconfigObject, reflectInfo reflect.Value) string {
	if reflectInfo.IsValid() {
		return metadataFromField(ctx, reflectInfo, "PfconfigNS")
	} else {
		return metadataFromField(ctx, o, "PfconfigNS")
	}
}

// Loads a resource and loads it from the process loaded resources unless the resource has changed in pfconfig
// A previously loaded PfconfigObject can be send to this method. If its previously loaded, it will not be touched if the namespace hasn't changed in pfconfig. If its previously loaded and has changed in pfconfig, the new data will be put in the existing PfconfigObject. Should field be unset or have disapeared in pfconfig, it will be properly set back to the zero value of the field. See https://play.golang.org/p/_dYY4Qe5_- for an example.
// Returns whether the resource has been loaded/reloaded from pfconfig or not
func (rp *ResourcePool) LoadResource(ctx context.Context, o PfconfigObject, reflectInfo reflect.Value, firstLoad bool) (bool, error) {
	structType := rp.getStructType(ctx, o, reflectInfo)
	namespace := rp.getNamespace(ctx, o, reflectInfo)

	structTypeStr := structType.String()

	alreadyLoaded := false

	// If this PfconfigObject was already loaded and hasn't changed since the load, then we can safely return and leave the current config untouched
	if res, ok := rp.FindResource(ctx, o); ok {
		alreadyLoaded = true
		if !firstLoad {
			if res.IsValid(ctx) {
				return false, nil
			} else {
				// If its invalid, its not already loaded
				alreadyLoaded = false
			}
		}
	}

	// We don't want to put a newer version of the resource in the map since another older struct relies on it
	// The new one (current) can safely rely on the data in it even though it is older
	if !alreadyLoaded {
		rp.loadedResources[structTypeStr] = Resource{
			namespace:  namespace,
			structType: structType,
			loadedAt:   time.Now(),
		}
	}

	err := FetchDecodeSocket(ctx, o, reflectInfo)
	return true, err
}

func (rp *ResourcePool) LoadResourceStruct(ctx context.Context, o PfconfigObject, firstLoad bool) (bool, error) {
	return rp.LoadResource(ctx, o, reflect.Value{}, firstLoad)
}
