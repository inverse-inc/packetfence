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
	"fingerbank_data_update":      NewFingerbankDataUpdate,
	"certificates_check":          NewCertificatesCheck,
	"cleanup_chi_database_cache":  NewChiCleanup,
	"bandwidth_maintenance":       NewBandwidthMaintenance,
	"admin_api_audit_log_cleanup": MakeWindowSqlJobSetupConfig(`DELETE FROM admin_api_audit_log WHERE created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`),
	"auth_log_cleanup":            MakeWindowSqlJobSetupConfig(`DELETE FROM auth_log WHERE attempted_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`),
	"dns_audit_log_cleanup":       MakeWindowSqlJobSetupConfig(`DELETE FROM dns_audit_log_cleanup WHERE created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`),
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
	"bandwidth_maintenance_session": MakeWindowSqlJobSetupConfig(
		`UPDATE bandwidth_accounting, (SELECT node_id, unique_session_id, MAX(last_updated) FROM bandwidth_accounting GROUP BY node_id, unique_session_id HAVING MAX(last_updated) < DATE_SUB(?, INTERVAL ? SECOND) AND MAX(last_updated) > '0000-00-00 00:00:00' LIMIT ?) as old_sessions SET last_updated = '0000-00-00 00:00:00' WHERE (bandwidth_accounting.node_id, bandwidth_accounting.unique_session_id) = (old_sessions.node_id, old_sessions.unique_session_id)`,
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

func SetupTask(config map[string]interface{}) Task {
	return Task{
		Type:         config["type"].(string),
		Status:       config["status"].(string),
		Description:  config["description"].(string),
		ScheduleSpec: config["schedule"].(string),
	}
}

func (t *Task) Schedule() cron.Schedule {
	s, _ := cron.ParseStandard(t.ScheduleSpec)
	return s
}

func (t *Task) Name() string {
	return t.Type
}
