package maint

import (
	"context"
	"time"
)

type ChiCleanup struct {
	Task
	Batch   int
	Timeout time.Duration
}

func (c *ChiCleanup) Run() {
	BatchSql(context.Background(), c.Timeout, `DELETE FROM chi_cache WHERE expires_at > ? LIMIT ?`, time.Now(), c.Batch)
}

func NewChiCleanup(config map[string]interface{}) JobSetupConfig {
	return &ChiCleanup{
		Task: Task{
			Type:         config["type"].(string),
			Status:       config["status"].(string),
			Description:  config["description"].(string),
			ScheduleSpec: config["schedule"].(string),
		},
		Batch:   int(config["batch"].(float64)),
		Timeout: time.Duration((config["timeout"].(float64))) * time.Second,
	}
}
