package maint

import (
	"os/exec"
)

type PfcronJob struct {
	Task
}

func (j *PfcronJob) Run() {
	cmd := exec.Command("/usr/local/pf/bin/pfcmd", "pfcron", j.Type)
	err := cmd.Run()
	_ = err
}

func NewPfcronJob(config map[string]interface{}) JobSetupConfig {
	return &PfcronJob{
		Task: SetupTask(config),
	}
}
