package maint

import (
	"github.com/inverse-inc/packetfence/go/redis_cache"
	"github.com/redis/go-redis/v9"
)

func redisClient() *redis.Client {
	return redis_cache.GetClient()
}
