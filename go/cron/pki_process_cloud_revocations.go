package maint

import (
	"context"
	"encoding/json"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

// PkiProcessCloudRevocations is the scheduled counterpart to the
// SCEP-retry hook in pfpki: it polls each cloud-enabled profile's
// revocation feed (currently Intune's CARevocationRequests) and applies
// any pending revocations locally. Running this on a slow cron (hourly)
// catches the rare case where a device is revoked in Intune but never
// re-enrolls via SCEP — the in-line retry only fires when SCEP traffic
// pulls it.
type PkiProcessCloudRevocations struct {
	Task
	API       string
	apiClient *unifiedapiclient.Client
	ctx       context.Context
}

func NewPkiProcessCloudRevocations(config map[string]interface{}) JobSetupConfig {
	ctx := context.Background()
	return &PkiProcessCloudRevocations{
		Task:      SetupTask(config),
		API:       "/api/v1/pki/process_cloud_revocations",
		apiClient: unifiedapiclient.NewFromConfig(ctx),
		ctx:       ctx,
	}
}

func (j *PkiProcessCloudRevocations) Run() {
	var raw json.RawMessage
	if err := j.apiClient.Call(j.ctx, "POST", j.API, &raw); err != nil {
		log.LogError(j.ctx, "Error calling "+j.apiClient.Host+": "+err.Error())
	}
}
