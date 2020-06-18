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
	"admin_api_audit_log_cleanup": MakeWindowSqlJobSetupConfig(`DELETE FROM admin_api_audit_log WHERE created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`),
	"auth_log_cleanup":            MakeWindowSqlJobSetupConfig(`DELETE FROM auth_log WHERE attempted_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`),
	"dns_audit_log":               MakeWindowSqlJobSetupConfig(`DELETE FROM dns_audit_log_cleanup WHERE created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`),
	"radius_audit_log_cleanup":    MakeWindowSqlJobSetupConfig(`DELETE FROM radius_audit_log WHERE created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`),
	"locationlog_cleanup": MakeMultiWindowSqlJobSetupConfig(
		`DELETE FROM locationlog_history WHERE end_time < DATE_SUB(?, INTERVAL ? SECOND) AND end_time != '0000-00-00 00:00:00' LIMIT ?`,
		`DELETE FROM locationlog WHERE end_time < DATE_SUB(?, INTERVAL ? SECOND) AND end_time != '0000-00-00 00:00:00' LIMIT ?`,
	),
	"acct_cleanup": MakeMultiWindowSqlJobSetupConfig(
		`UPDATE radacct SET acctstoptime = NOW() WHERE acctstarttime < DATE_SUB(?, INTERVAL ? SECOND) AND acctstoptime IS NULL LIMIT ?`,
		`DELETE FROM radacct WHERE acctstarttime < DATE_SUB(?, INTERVAL ? SECOND) AND acctstoptime IS NOT NULL LIMIT ?`,
		`DELETE FROM radacct_log WHERE timestamp < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`,
	),
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
