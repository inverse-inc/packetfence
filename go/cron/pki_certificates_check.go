package maint

import (
	"context"
	"encoding/json"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

type PkiCertificatesCheck struct {
	Task
	API       string
	apiClient *unifiedapiclient.Client
}

func (j *PkiCertificatesCheck) RunWithContext(ctx context.Context) {
	var raw json.RawMessage
	err := j.apiClient.Call(ctx, "GET", j.API, &raw)
	if err != nil {
		log.LogError(ctx, "Error calling "+j.apiClient.Host+": "+err.Error())
	}
}

type PkiUnVerifyFileCert struct {
	Path    string
	Message string
}

func NewPkiCertificatesCheck(config map[string]interface{}) JobSetupConfig {
	ctx := context.Background()
	return &PkiCertificatesCheck{
		Task:      SetupTask(config),
		API:       "/api/v1/pki/checkrenewal",
		apiClient: unifiedapiclient.NewFromConfig(ctx),
	}
}

func (j *PkiCertificatesCheck) Run() {
	j.RunWithContext(context.Background())
}
