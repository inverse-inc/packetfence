package maint

import (
	"time"
)

type LocationLogCleanup struct {
	Task
	Window  int
	Batch   int
	Timeout time.Duration
	StmtSetup
}

func NewLocationLogCleanup(config map[string]interface{}) JobSetupConfig {
	return &LocationLogCleanup{
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

func (c *LocationLogCleanup) Run() {
	stmt := c.Stmt(`DELETE FROM locationlog_history WHERE end_time < DATE_SUB(?, INTERVAL ? SECOND) AND != '0000-00-00 00:00:00' LIMIT ?`)
	if stmt != nil {
		BatchStmt(stmt, c.Timeout, time.Now(), c.Window, c.Batch)
	}
}
