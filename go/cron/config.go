package maint

import (
	"context"
	"reflect"

	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/robfig/cron/v3"
)

var CachedCronConfig = pfconfigdriver.NewCachedValue(reflect.TypeOf(pfconfigdriver.Cron{}))

type JobSetupConfig interface {
	cron.Job
	Schedule() cron.Schedule
	ScheduleSpec() string
	Name() string
	ForceLocal() bool
}

var builders = map[string]func(map[string]interface{}) JobSetupConfig{
	"fingerbank_data_update":       NewFingerbankDataUpdate,
	"certificates_check":           NewCertificatesCheck,
	"pki_certificates_check":       NewPkiCertificatesCheck,
	"file_logger":                  NewFileLogger,
	"cleanup_chi_database_cache":   NewChiCleanup,
	"bandwidth_maintenance":        NewBandwidthMaintenance,
	"ip4log_cleanup":               NewIp4logCleanup,
	"ip6log_cleanup":               NewIp6logCleanup,
	"flush_dns_audit_log":          NewFlushDNSAuditLog,
	"pfflow":                       NewPfFlowJob,
	"purge_binary_logs":            MakeSingleWindowSqlJobSetupConfig(`PURGE BINARY LOGS BEFORE (NOW() - INTERVAL ? SECOND)`),
	"admin_api_audit_log_cleanup":  MakeWindowSqlJobSetupConfig(`DELETE FROM admin_api_audit_log WHERE created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`),
	"auth_log_cleanup":             MakeWindowSqlJobSetupConfig(`DELETE FROM auth_log WHERE attempted_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`),
	"dns_audit_log_cleanup":        MakeWindowSqlJobSetupConfig(`DELETE FROM dns_audit_log WHERE created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`),
	"radius_audit_log_cleanup":     MakeWindowSqlJobSetupConfig(`DELETE FROM radius_audit_log WHERE created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`),
	"node_current_session_cleanup": MakeWindowSqlJobSetupConfig(`DELETE FROM node_current_session WHERE updated < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`),
	"locationlog_cleanup": MakeMultiWindowSqlJobSetupConfig(
		`DELETE FROM locationlog_history WHERE end_time < DATE_SUB(?, INTERVAL ? SECOND) AND end_time != '0000-00-00 00:00:00' LIMIT ?`,
		`DELETE FROM locationlog WHERE end_time < DATE_SUB(?, INTERVAL ? SECOND) AND end_time != '0000-00-00 00:00:00' LIMIT ?`,
	),
	"acct_cleanup": MakeMultiWindowSqlJobSetupConfig(
		`UPDATE radacct SET acctstoptime = NOW() WHERE acctstarttime < DATE_SUB(?, INTERVAL ? SECOND) AND acctstoptime IS NULL LIMIT ?`,
		`DELETE FROM radacct WHERE acctstarttime < DATE_SUB(?, INTERVAL ? SECOND) AND acctstoptime IS NOT NULL LIMIT ?`,
		`DELETE FROM radacct_log WHERE timestamp < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`,
	),
	"flush_radius_audit_log": NewFlushRadiusAuditLogJob,
}

func GetMaintenanceConfig(ctx context.Context) map[string]interface{} {
	o, _ := CachedCronConfig.Value(ctx)
	if o != nil {
		tasks := o.(*pfconfigdriver.Cron)
		return tasks.Element
	}

	return nil
}

func MergeArgs(a, b map[string]interface{}) map[string]interface{} {
	newArgs := make(map[string]interface{})
	for k, v := range a {
		newArgs[k] = v
	}

	for k, v := range b {
		newArgs[k] = v
	}

	return newArgs
}

func GetConfiguredJobs(maintConfig map[string]interface{}) []JobSetupConfig {
	jobs := []JobSetupConfig{}
	for name, config := range maintConfig {
		data := config.(map[string]interface{})
		if data["status"].(string) == "enabled" {
			if job := BuildJob(name, data); job != nil {
				jobs = append(jobs, job)
			}
		}
	}

	return jobs
}

func GetJob(name string, jobsConfig map[string]interface{}) JobSetupConfig {
	if config, found := jobsConfig[name]; found {
		return BuildJob(name, config.(map[string]interface{}))
	}

	return nil
}

func BuildJob(name string, config map[string]interface{}) JobSetupConfig {
	var constructor func(map[string]interface{}) JobSetupConfig
	var found bool
	if constructor, found = builders[name]; !found {
		constructor = NewPfcronJob
	}
	return constructor(config)
}

type Task struct {
	Type            string `json:"type"`
	Status          string `json:"status"`
	Description     string `json:"description"`
	ScheduleSpecStr string `json:"schedule"`
	Local           string `json:"local"`
}

func SetupTask(config map[string]interface{}) Task {
	return Task{
		Type:            config["type"].(string),
		Status:          config["status"].(string),
		Description:     config["description"].(string),
		ScheduleSpecStr: config["schedule"].(string),
		Local:           config["local"].(string),
	}
}

func (t *Task) Schedule() cron.Schedule {
	s, _ := cron.ParseStandard(t.ScheduleSpecStr)
	return s
}

func (t *Task) ScheduleSpec() string {
	return t.ScheduleSpecStr
}

func (t *Task) Name() string {
	return t.Type
}

func (t *Task) ForceLocal() bool {
	return sharedutils.IsEnabled(t.Local)
}
