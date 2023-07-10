package maint

import (
	"github.com/go-redis/redis/v8"
	"github.com/inverse-inc/packetfence/go/redis_cache"
)

func redisClient() *redis.Client {
	return redis_cache.GetClient()
}
