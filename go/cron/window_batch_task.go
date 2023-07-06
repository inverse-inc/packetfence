package maint

import (
	"context"
	"fmt"
	"time"

	"github.com/inverse-inc/go-utils/log"
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
		Task:    SetupTask(config),
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
	count, _ := BatchSql(context.Background(), c.Timeout, c.Sql, time.Now(), c.Window, c.Batch)
	if count > -1 {
		log.LogInfo(context.Background(), fmt.Sprintf("%s cleaned items %d", c.Name(), count))
	}
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
		Task:    SetupTask(config),
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

type SingleWindowSqlCleanup struct {
	Task
	Window int
	Sql    string
}

func NewSingleWindowSqlCleanup(config map[string]interface{}, sql string) JobSetupConfig {
	return &SingleWindowSqlCleanup{
		Task:   SetupTask(config),
		Window: int(config["window"].(float64)),
		Sql:    sql,
	}
}

func (c *SingleWindowSqlCleanup) Run() {
	err := BatchSingleSql(context.Background(), c.Sql, c.Window)
	if err != nil {
		log.LogError(context.Background(), fmt.Sprintf("%s on sql query", err))
	}
}

func MakeSingleWindowSqlJobSetupConfig(sql string) func(config map[string]interface{}) JobSetupConfig {
	return func(config map[string]interface{}) JobSetupConfig {
		return NewSingleWindowSqlCleanup(config, sql)
	}
}
