package connector

import (
	"context"

	"github.com/go-redis/redis"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

var redisClient *redis.Client
var redisTunnelsNamespace string

func init() {
	pfconfigdriver.PfconfigPool.AddStruct(context.Background(), &pfconfigdriver.Config.PfConf.Pfconnector)
	var network string
	if pfconfigdriver.Config.PfConf.Pfconnector.RedisServer[0] == '/' {
		network = "unix"
	} else {
		network = "tcp"
	}

	redisClient = redis.NewClient(&redis.Options{
		Addr:    pfconfigdriver.Config.PfConf.Pfconnector.RedisServer,
		Network: network,
	})
	redisTunnelsNamespace = pfconfigdriver.Config.PfConf.Pfconnector.RedisTunnelsNamespace
}
