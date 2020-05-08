package maint

import (
	"time"
)

type AdminApiAuditLogCleanup struct {
	Task
	Window  int
	Batch   int
	Timeout time.Duration
	StmtSetup
}

func NewAdminApiAuditLogCleanup(config map[string]interface{}) JobSetupConfig {
	return &AdminApiAuditLogCleanup{
		Task: Task{
			Type:         config["type"].(string),
			Status:       config["status"].(string),
			Description:  config["description"].(string),
			ScheduleSpec: config["schedule"].(string),
		},
		Batch:   int(config["batch"].(float64)),
		Timeout: time.Duration((config["timeout"].(float64))) * time.Second,
		Window:  int(config["window"].(float64)),
	}
}

func (c *AdminApiAuditLogCleanup) Run() {
	stmt := c.Stmt(`DELETE FROM admin_api_audit_log WHERE created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`)
	if stmt != nil {
		BatchRemove(stmt, c.Timeout, time.Now(), c.Window, c.Batch)
	}
}
