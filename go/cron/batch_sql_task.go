package maint

import (
	"context"
	"fmt"
	"time"

	"github.com/inverse-inc/go-utils/log"
)

// BatchSqlCleanup runs a batched SQL statement that has no time window: the
// statement's own predicates decide what is affected. The only bind parameter
// is the LIMIT.
type BatchSqlCleanup struct {
	Task
	Batch   int
	Timeout time.Duration
	Sql     string
}

func NewBatchSqlCleanup(config map[string]interface{}, sql string) JobSetupConfig {
	return &BatchSqlCleanup{
		Task:    SetupTask(config),
		Batch:   int(config["batch"].(float64)),
		Timeout: time.Duration((config["timeout"].(float64))) * time.Second,
		Sql:     sql,
	}
}

func MakeBatchSqlJobSetupConfig(sql string) func(config map[string]interface{}) JobSetupConfig {
	return func(config map[string]interface{}) JobSetupConfig {
		return NewBatchSqlCleanup(config, sql)
	}
}

func (c *BatchSqlCleanup) Run() {
	count, _ := BatchSql(context.Background(), c.Timeout, c.Sql, c.Batch)
	if count > -1 {
		log.LogInfo(context.Background(), fmt.Sprintf("%s cleaned items %d", c.Name(), count))
	}
}
