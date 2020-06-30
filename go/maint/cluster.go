package maint

import (
	"context"
	"os"

	"github.com/inverse-inc/packetfence/go/jsonrpc2"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type Server struct {
	Host         string `json:"host"`
	ManagementIp string `json:"management_ip"`
}

func (s *Server) IsDisabled() bool {
	filename := "/usr/local/pf/var/run/" + s.Host + "-cluster-disabled"
	info, err := os.Stat(filename)
	if os.IsNotExist(err) {
		return false
	}

	return !info.IsDir()
}

func CallCluster(ctx context.Context, method string, args interface{}) {
	clientApi := jsonrpc2.NewClientFromConfig(context.Background())
	clientApi.Proto = "https"
	for _, member := range enabledServers(ctx) {
		clientApi.Host = member.ManagementIp
		if _, err := clientApi.Call(ctx, method, args, 1); err != nil {
			logError(ctx, "Error calling "+clientApi.Host+": "+err.Error())
		}
	}
}

func NotifyCluster(ctx context.Context, method string, args interface{}) {
	clientApi := jsonrpc2.NewClientFromConfig(context.Background())
	clientApi.Proto = "https"
	for _, member := range enabledServers(ctx) {
		clientApi.Host = member.ManagementIp
		if _, err := clientApi.Notify(ctx, method, args, 1); err != nil {
			logError(ctx, "Error calling "+clientApi.Host+": "+err.Error())
		}
	}
}

func enabledServers(ctx context.Context) []Server {
	servers := []Server{}
	cluster_servers := pfconfigdriver.AllClusterServers{}
	pfconfigdriver.FetchDecodeSocketCache(ctx, &cluster_servers)
	for _, s := range cluster_servers.Element {
		server := Server{Host: s.Host, ManagementIp: s.ManagementIp}
		if !server.IsDisabled() {
			servers = append(servers, server)
		}
	}

	return servers
}
