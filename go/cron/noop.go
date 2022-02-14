package maint

type Noop struct {
	Task
}

func (j *Noop) Run() {
}

func NewNoop(config map[string]interface{}) JobSetupConfig {
	return &Noop{
		Task: SetupTask(config),
	}
}
