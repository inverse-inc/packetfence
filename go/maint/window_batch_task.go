package maint

import (
	"context"
	"time"
)

type WindowSqlCleanup struct {
	Task
	Window  int
	Batch   int
	Timeout time.Duration
	Sql     string
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
	BatchSql(context.Background(), c.Timeout, c.Sql, time.Now(), c.Window, c.Batch)
}

type MultiWindowSqlCleanup struct {
	Task
	Window  int
	Batch   int
	Timeout time.Duration
	Sqls    []string
}

func NewMultiWindowSqlCleanup(config map[string]interface{}, sqls ...string) JobSetupConfig {
	sqlStrings := make([]string, len(sqls))
	copy(sqlStrings, sqls)
	return &MultiWindowSqlCleanup{
		Task: Task{
			Type:         config["type"].(string),
			Status:       config["status"].(string),
			Description:  config["description"].(string),
			ScheduleSpec: config["schedule"].(string),
		},
		Batch:   int(config["batch"].(float64)),
		Timeout: time.Duration((config["timeout"].(float64))) * time.Second,
		Window:  int(config["window"].(float64)),
		Sqls:    sqlStrings,
	}
}

func (c *MultiWindowSqlCleanup) Run() {
	now := time.Now()
	for _, sql := range c.Sqls {
		BatchSql(context.Background(), c.Timeout, sql, now, c.Window, c.Batch)
	}
}

func MakeMultiWindowSqlJobSetupConfig(sqls ...string) func(config map[string]interface{}) JobSetupConfig {
	return func(config map[string]interface{}) JobSetupConfig {
		return NewMultiWindowSqlCleanup(config, sqls...)
	}
}
