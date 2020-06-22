package maint

import (
	"time"
)

type BandwidthMaintenance struct {
	Task
	Window         int
	Batch          int
	Timeout        time.Duration
	HistoryWindow  int
	HistoryBatch   int
	HistoryTimeout time.Duration
}

func NewBandwidthMaintenance(config map[string]interface{}) JobSetupConfig {
	return &BandwidthMaintenance{
		Task: Task{
			Type:         config["type"].(string),
			Status:       config["status"].(string),
			Description:  config["description"].(string),
			ScheduleSpec: config["schedule"].(string),
		},
		Batch:          int(config["batch"].(float64)),
		Timeout:        time.Duration((config["timeout"].(float64))) * time.Second,
		Window:         int(config["window"].(float64)),
		HistoryBatch:   int(config["history_batch"].(float64)),
		HistoryTimeout: time.Duration((config["history_timeout"].(float64))) * time.Second,
		HistoryWindow:  int(config["history_window"].(float64)),
	}
}

func (j *BandwidthMaintenance) Run() {
	j.ProcessBandwidthAccountingNetflow()
	j.TriggerBandwidth()
	j.BandwidthAggregation("hourly", "DATE_SUB(NOW(), INTERVAL ? HOUR)", 2)
	j.BandwidthAggregation("daily", "DATE_SUB(NOW(), INTERVAL ? DAY)", 2)
	j.BandwidthAggregation("monthly", "DATE_SUB(NOW(), INTERVAL ? MONTHLY)", 1)
	j.BandwidthAccountingRadiusToHistory()
	j.BandwidthAggregationHistoryDaily()
	j.BandwidthAggregationHistoryMonthly()
	j.BandwidthAccountingHistoryCleanup()
}

func (j *BandwidthMaintenance) ProcessBandwidthAccountingNetflow() {
}

func (j *BandwidthMaintenance) TriggerBandwidth() {
}

func (j *BandwidthMaintenance) BandwidthAggregation(rounding string, date_sql string, interval int) {
}

func (j *BandwidthMaintenance) BandwidthAccountingRadiusToHistory() {}
func (j *BandwidthMaintenance) BandwidthAggregationHistoryDaily()   {}
func (j *BandwidthMaintenance) BandwidthAggregationHistoryMonthly() {}
func (j *BandwidthMaintenance) BandwidthAccountingHistoryCleanup()  {}
