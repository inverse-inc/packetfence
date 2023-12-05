package connector

import (
	"context"
	"os"

	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/redis/go-redis/v9"
)

var redisClient *redis.Client
var redisTunnelsNamespace string

func init() {
	// The pfconnector-remote doesn't have pfconfig nor redis
	if sharedutils.IsEnabled(os.Getenv("PFCONNECTOR_REMOTE")) {
		return
	}

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
