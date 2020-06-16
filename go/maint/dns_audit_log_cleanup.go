package maint

import (
	"time"
)

type DNSAuditLogCleanup struct {
	Task
	Window  int
	Batch   int
	Timeout time.Duration
	StmtSetup
}

func NewDNSAuditLogCleanup(config map[string]interface{}) JobSetupConfig {
	return &DNSAuditLogCleanup{
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

func (c *DNSAuditLogCleanup) Run() {
	stmt := c.Stmt(`DELETE FROM dns_audit_log_cleanup WHERE created_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`)
	if stmt != nil {
		BatchStmt(stmt, c.Timeout, time.Now(), c.Window, c.Batch)
	}
}
