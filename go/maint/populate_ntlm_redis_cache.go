package maint

type PopulateNtlmRedisCache struct {
	Task
}

func NewPopulateNtlmRedisCache(config map[string]interface{}) JobSetupConfig {
	return &PopulateNtlmRedisCache{
		Task: SetupTask(config),
	}
}

func (j *PopulateNtlmRedisCache) Run() {}
