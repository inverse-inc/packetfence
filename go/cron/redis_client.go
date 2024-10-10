package maint

import (
	"sync"

	"github.com/inverse-inc/packetfence/go/redis_cache"
	"github.com/redis/go-redis/v9"
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
