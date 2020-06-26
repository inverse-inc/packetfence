package maint

func NewFingerbankDataUpdate(config map[string]interface{}) JobSetupConfig {
	return &FingerbankDataUpdate{
		Task: SetupTask(config),
	}
}

type FingerbankDataUpdate struct {
	Task
}

func (j *FingerbankDataUpdate) Run() {
}
