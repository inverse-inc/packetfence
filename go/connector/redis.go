package connector

import (
	"context"
	"os"
	"sync"

	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/redis/go-redis/v9"
)

var (
	redisOnce             sync.Once
	redisClient           *redis.Client
	redisTunnelsNamespace string
)

// tunnelsRedis is the Redis of the pfconnector servers (which instance holds
// the tunnel of a connector), connected on first use: importing this package
// does not need pfconfig
func tunnelsRedis() (*redis.Client, string) {
	redisOnce.Do(func() {
		// The pfconnector-remote doesn't have pfconfig nor redis
		if sharedutils.IsEnabled(os.Getenv("PFCONNECTOR_REMOTE")) {
			return
		}

		pfConnector := pfconfigdriver.GetType[pfconfigdriver.PfConfPfconnector](context.Background())
		var network string
		if pfConnector.RedisServer[0] == '/' {
			network = "unix"
		} else {
			network = "tcp"
		}

		redisClient = redis.NewClient(&redis.Options{
			Addr:    pfConnector.RedisServer,
			Network: network,
		})
		redisTunnelsNamespace = pfConnector.RedisTunnelsNamespace
	})
	return redisClient, redisTunnelsNamespace
}

// tunnelsRedisClient is the client of tunnelsRedis
func tunnelsRedisClient() *redis.Client {
	client, _ := tunnelsRedis()
	return client
}
