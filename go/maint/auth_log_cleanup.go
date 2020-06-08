package maint

import (
	"time"
)

type AuthLogCleanup struct {
	Task
	Window  int
	Batch   int
	Timeout time.Duration
	StmtSetup
}

func NewAuthLogCleanup(config map[string]interface{}) JobSetupConfig {
	return &AuthLogCleanup{
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

func (c *AuthLogCleanup) Run() {
	stmt := c.Stmt(`DELETE FROM auth_log WHERE attempted_at < DATE_SUB(?, INTERVAL ? SECOND) LIMIT ?`)
	if stmt != nil {
		BatchRemove(stmt, c.Timeout, time.Now(), c.Window, c.Batch)
	}
}
