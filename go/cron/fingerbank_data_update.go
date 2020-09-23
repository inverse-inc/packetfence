package maint

import (
	"context"
	"github.com/inverse-inc/packetfence/go/cluster"
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
	cluster.CallCluster(
		ctx,
		"fingerbank_update_component",
		[]interface{}{
			"action", "update-upstream-db",
			"email_admin", 0,
			"fork_to_queue", 1,
		},
	)
}
