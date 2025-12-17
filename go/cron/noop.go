package maint

import "context"

type Noop struct {
	Task
}

func (j *Noop) Run() {
	j.RunWithContext(context.Background())
}

func (j *Noop) RunWithContext(ctx context.Context) {
}

func NewNoop(config map[string]interface{}) JobSetupConfig {
	return &Noop{
		Task: SetupTask(config),
	}
}
