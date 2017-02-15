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

type Resource struct {
	pfconfigObject PfconfigObject
	namespace      string
	structType     reflect.Type
	loadedAt       time.Time
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

// Loads a resource and loads it from the process loaded resources unless the resource has changed in pfconfig
// A previously loaded PfconfigObject can be send to this method. If its previously loaded, it will not be touched if the namespace hasn't changed in pfconfig. If its previously loaded and has changed in pfconfig, the new data will be put in the existing PfconfigObject. Should field be unset or have disapeared in pfconfig, it will be properly set back to the zero value of the field. See https://play.golang.org/p/_dYY4Qe5_- for an example.
func (rp *ResourcePool) LoadResource(ctx context.Context, resource PfconfigObject, firstLoad bool) {
	structType := reflect.TypeOf(resource).Elem()
	structTypeStr := structType.String()

	// If this PfconfigObject was already loaded and hasn't changed since the load, then we can safely return and leave the current config untouched
	if !firstLoad {
		if res, ok := rp.loadedResources[structTypeStr]; ok {
			if res.IsValid(ctx) {
				return
			}
		}
	}

	namespace := metadataFromField(ctx, resource, "PfconfigNS")

	rp.loadedResources[structTypeStr] = Resource{
		pfconfigObject: &resource,
		namespace:      namespace,
		structType:     structType,
		loadedAt:       time.Now(),
	}

	FetchDecodeSocketStruct(ctx, resource)
}
