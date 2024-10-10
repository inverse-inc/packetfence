package redisclient

import (
	"context"
	"sync"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/mediocregopher/radix.v2/pool"
	"github.com/mediocregopher/radix.v2/redis"
)

type PfqueueConsumerConfig struct {
	pfconfigdriver.StructConfig
	PfconfigMethod string          `val:"hash_element"`
	PfconfigNS     string          `val:"config::Pfqueue"`
	PfconfigHashNS string          `val:"consumer"`
	RedisArgs      RedisArgsConfig `json:"redis_args"`
}

type RedisArgsConfig struct {
	Reconnect pfconfigdriver.PfInt `json:"reconnect"`
	Every     pfconfigdriver.PfInt `json:"every"`
	Server    string               `json:"server"`
}

func dial(network, addr string) (*redis.Client, error) {
	client, err := redis.Dial(network, addr)
	if err != nil {
		return nil, err
	}
	return client, err
}

var poolOnce sync.Once
var clientPool *pool.Pool

func GetPfQueueRedisClient(ctx context.Context) (*redis.Client, error) {
	poolOnce.Do(func() {
		config := pfconfigdriver.GetType[PfqueueConsumerConfig](context.Background())
		var network string = "tcp"
		if config.RedisArgs.Server[0] == '/' {
			network = "unix"
		}
		clientPool, _ = pool.NewCustom(network, config.RedisArgs.Server, 100, dial)
	})

	return clientPool.Get()
}

func PutPfQueueRedisClient(c *redis.Client) {
	clientPool.Put(c)
}
