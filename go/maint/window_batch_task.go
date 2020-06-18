package maint

import (
	"time"
)

type WindowSqlCleanup struct {
	Task
	Window  int
	Batch   int
	Timeout time.Duration
	Sql     string
	StmtSetup
}

func NewWindowSqlCleanup(config map[string]interface{}, sql string) JobSetupConfig {
	return &WindowSqlCleanup{
		Task: Task{
			Type:         config["type"].(string),
			Status:       config["status"].(string),
			Description:  config["description"].(string),
			ScheduleSpec: config["schedule"].(string),
		},
		Batch:   int(config["batch"].(float64)),
		Timeout: time.Duration((config["timeout"].(float64))) * time.Second,
		Window:  int(config["window"].(float64)),
		Sql:     sql,
	}
}

func MakeWindowSqlJobSetupConfig(sql string) func(config map[string]interface{}) JobSetupConfig {
	return func(config map[string]interface{}) JobSetupConfig {
		return NewWindowSqlCleanup(config, sql)
	}
}

func (c *WindowSqlCleanup) Run() {
	stmt := c.Stmt(c.Sql)
	if stmt != nil {
		BatchStmt(stmt, c.Timeout, time.Now(), c.Window, c.Batch)
	}
}
