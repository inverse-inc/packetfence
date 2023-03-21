package maint

import (
	"context"
	"fmt"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

type PfcronJob struct {
	Task
}

func (j *PfcronJob) Run() {
	ctx := context.Background()
	client := unifiedapiclient.NewFromConfig(ctx)
	url := "/api/v1/config/maintenance_task/" + j.Type + "/run"
	response := map[string]interface{}{}
	err := client.CallWithBody(
		ctx,
		"POST",
		url,
		map[string]interface{}{},
		&response,
	)

	if err != nil {
		log.LogError(ctx, fmt.Sprintf("pfcmd pfcron: %s", err.Error()))
	} else {
		log.LogInfo(ctx, fmt.Sprintf("API call %s", url))
	}
}

func NewPfcronJob(config map[string]interface{}) JobSetupConfig {
	return &PfcronJob{
		Task: SetupTask(config),
	}
}
