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
}
