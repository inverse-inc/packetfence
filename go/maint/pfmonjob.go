package maint

import (
	"os/exec"
)

type PfmonJob struct {
	Task
}

func (j *PfmonJob) Run() {
	cmd := exec.Command("/usr/local/pf/bin/pfcmd", "pfmon", j.Type)
	err := cmd.Run()
	_ = err
}

func NewPfmonJob(config map[string]interface{}) JobSetupConfig {
	return &PfmonJob{
		Task: Task{
			Type:         config["type"].(string),
			Status:       config["status"].(string),
			Description:  config["description"].(string),
			ScheduleSpec: config["schedule"].(string),
		},
	}
}
