package maint

import (
	"sync"

	"github.com/go-redis/redis/v8"
	"github.com/inverse-inc/packetfence/go/redis_cache"
)

var redisClient *redis.Client
var redisClientOnce sync.Once

func getRedisClient() *redis.Client {
	redisClientOnce.Do(
		func() {
			redisClient = redis_cache.GetClient()
		},
	)

	return redisClient
}
