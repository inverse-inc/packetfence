package maint

import (
	"github.com/robfig/cron/v3"
    "time"
)

type JobSetupConfig struct {
	Job      cron.Job
	Schedule cron.Schedule
}

func GetConfiguredJobs() []JobSetupConfig {
	return []JobSetupConfig{
		{NewPfmonJob("acct_maintenance"), cron.Every(1 * time.Minute)},
	}
}
