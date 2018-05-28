package redisclient

import (
	"context"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/mediocregopher/radix.v2/pool"
	"github.com/mediocregopher/radix.v2/redis"
	"sync"
)

type PfqueueConsumerConfig struct {
	pfconfigdriver.StructConfig
	PfconfigMethod string          `val:"hash_element"`
	PfconfigNS     string          `val:"config::Pfqueue"`
	PfconfigHashNS string          `val:"consumer"`
	RedisArgs      RedisArgsConfig `json:"redis_args"`
}

type RedisArgsConfig struct {
	Reconnect string `json:"reconnect"`
	Every     string `json:"every"`
	Server    string `json:"server"`
}

var Config = PfqueueConsumerConfig{
	PfconfigNS:     "config::Pfqueue",
	PfconfigHashNS: "consumer",
	PfconfigMethod: "hash_element",
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
		pfconfigdriver.PfconfigPool.AddStruct(ctx, &Config)
		var network string = "tcp"
		if Config.RedisArgs.Server[0] == '/' {
			network = "unix"
		}
		clientPool, _ = pool.NewCustom(network, Config.RedisArgs.Server, 100, dial)
	})

	return clientPool.Get()
}

func PutPfQueueRedisClient(c *redis.Client) {
    clientPool.Put(c)
}
