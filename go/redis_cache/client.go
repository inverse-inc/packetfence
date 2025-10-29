package redis_cache

import (
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/redis/go-redis/v9"
)

func GetClient() *redis.Client {
	hostname := sharedutils.EnvOrDefault("REDIS_CACHE_HOST", "127.0.0.1")
	port := sharedutils.EnvOrDefault("REDIS_CACHE_PORT", "6379")
	return redis.NewClient(&redis.Options{
		Addr:     hostname + ":" + port,
		Password: "", // no password set
		DB:       0,  // use default DB
	})
}
