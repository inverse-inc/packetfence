package maint

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
	return &WindowSqlCleanup{
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
}
