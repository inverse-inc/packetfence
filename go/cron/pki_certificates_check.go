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
	ctx       context.Context
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
		ctx:       ctx,
	}
}

func (j *PkiCertificatesCheck) Run() {
	var raw json.RawMessage
	err := j.apiClient.Call(j.ctx, "GET", j.API, &raw)
	if err != nil {
		log.LogError(j.ctx, "Error calling "+j.apiClient.Host+": "+err.Error())
	}
}
