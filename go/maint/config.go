package maint

import (
	"context"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/robfig/cron/v3"
)

type JobSetupConfig interface {
	cron.Job
	Schedule() cron.Schedule
	Name() string
}

var builders = map[string]func(map[string]interface{}) JobSetupConfig{
	"cleanup_chi_database_cache":  NewChiCleanup,
	"admin_api_audit_log_cleanup": NewAdminApiAuditLogCleanup,
	"auth_log_cleanup":            NewAuthLogCleanup,
	"dns_audit_log":               NewDNSAuditLogCleanup,
	"locationlog_cleanup":         NewLocationLogCleanup,
}

func GetConfiguredJobs() []JobSetupConfig {
	var tasks pfconfigdriver.Maintenance
	ctx := context.Background()
	pfconfigdriver.FetchDecodeSocket(ctx, &tasks)
	jobs := []JobSetupConfig{}
	for name, config := range tasks.Element {
		data := config.(map[string]interface{})
		if data["status"].(string) == "enabled" {
			var constructor func(map[string]interface{}) JobSetupConfig
			var found bool
			if constructor, found = builders[name]; !found {
				constructor = NewPfmonJob
			}

			if job := constructor(data); job != nil {
				jobs = append(jobs, job)
			}
		}
	}

	return jobs
}

type Task struct {
	Type         string `json:"type"`
	Status       string `json:"status"`
	Description  string `json:"description"`
	ScheduleSpec string `json:"schedule"`
}

func (t *Task) Schedule() cron.Schedule {
	s, _ := cron.ParseStandard(t.ScheduleSpec)
	return s
}

func (t *Task) Name() string {
	return t.Type
}
