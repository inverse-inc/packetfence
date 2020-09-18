package maint

import (
	"context"
	"fmt"
	"github.com/inverse-inc/packetfence/go/log"
	"os/exec"
)

type PfcronJob struct {
	Task
}

func (j *PfcronJob) Run() {
	cmd := exec.Command("/usr/local/pf/bin/pfcmd", "pfcron", j.Type)
	err := cmd.Run()
	if err != nil {
		log.LoggerWContext(context.Background()).Error(fmt.Sprintf("pfcmd pfcron: %s", err.Error()))
	}
}

func NewPfcronJob(config map[string]interface{}) JobSetupConfig {
	return &PfcronJob{
		Task: SetupTask(config),
	}
}
