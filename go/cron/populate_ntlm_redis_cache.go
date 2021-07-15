package maint

import (
	"context"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/cluster"
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"reflect"
)

var CachedNtlmRedisCachedDomains = pfconfigdriver.NewCachedValue(reflect.TypeOf(pfconfigdriver.NtlmRedisCachedDomains{}))

type PopulateNtlmRedisCache struct {
	Task
}

func NewPopulateNtlmRedisCache(config map[string]interface{}) JobSetupConfig {
	return &PopulateNtlmRedisCache{
		Task: SetupTask(config),
	}
}

func (j *PopulateNtlmRedisCache) Run() {
	ctx := context.Background()
	for _, d := range GetCachedNtlmRedisCachedDomains(ctx) {
		sendQueueJob(ctx, d)
	}
}

func GetCachedNtlmRedisCachedDomains(ctx context.Context) []string {
	o, _ := CachedNtlmRedisCachedDomains.Value(ctx)
	if o != nil {
		domains := o.(*pfconfigdriver.NtlmRedisCachedDomains)
		return domains.Element
	}

	return nil
}

func sendQueueJob(ctx context.Context, domain string) {
	method := "queue_job"
	args := []interface{}{
		"general",
		"populate_ntlm_cache",
		domain,
	}
	if !cluster.CallCluster(ctx, method, args, 1) {
		clientApi := jsonrpc2.NewClientFromConfig(ctx)
		if _, err := clientApi.Call(ctx, method, args, 1); err != nil {
			log.LogError(ctx, "Error calling "+clientApi.Host+": "+err.Error())
		}
	}
}
