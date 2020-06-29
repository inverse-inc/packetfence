package maint

import (
	"context"
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
)

type Server struct {
}

func CallCluster(ctx context.Context, async bool, method string, args interface{}) {
    clientApi := jsonrpc2.NewClientFromConfig(context.Background())
    _ = clientApi
	for _, member := range enabledServers(ctx) {
		_ = member
	}
}

func enabledServers(ctx context.Context) []Server {
	servers := []Server{}
	return servers
}
