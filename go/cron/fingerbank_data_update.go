package maint

import (
	"context"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/cluster"
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
	"github.com/davecgh/go-spew/spew"
)

func NewFingerbankDataUpdate(config map[string]interface{}) JobSetupConfig {
	return &FingerbankDataUpdate{
		Task: SetupTask(config),
	}
}

type FingerbankDataUpdate struct {
	Task
}

func (j *FingerbankDataUpdate) Run() {
	ctx := context.Background()
	method := "fingerbank_update_component"
	args := []interface{}{
		"action", "update-upstream-db",
		"email_admin", 0,
		"fork_to_queue", 1,
	}
	if !cluster.CallCluster(ctx, method, args) {
		clientApi := jsonrpc2.NewClientFromConfig(ctx)
		spew.Dump(clientApi)
		if _, err := clientApi.Call(ctx, method, args); err != nil {
			log.LogError(ctx, "Error calling "+clientApi.Host+": "+err.Error())
		}
	}
}
