package maint

type Ip6logCleanup struct {
	Task
}

func NewIp6logCleanup(config map[string]interface{}) JobSetupConfig {
	return &Ip6logCleanup{
		Task: SetupTask(config),
	}
}

func (j *Ip6logCleanup) Run() {}
