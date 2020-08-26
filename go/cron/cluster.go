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
	servers, cluster_mode := enabledServers(ctx)
	if cluster_mode {
		clientApi := jsonrpc2.NewClientFromConfig(context.Background())
		clientApi.Proto = "https"
		for _, member := range servers {
			clientApi.Host = member.ManagementIp
			if _, err := clientApi.Call(ctx, method, args, 1); err != nil {
				logError(ctx, "Error calling "+clientApi.Host+": "+err.Error())
			}
		}
	}
}

func NotifyCluster(ctx context.Context, method string, args interface{}) {
	servers, cluster_mode := enabledServers(ctx)
	if cluster_mode {
		clientApi := jsonrpc2.NewClientFromConfig(context.Background())
		clientApi.Proto = "https"
		for _, member := range servers {
			clientApi.Host = member.ManagementIp
			if err := clientApi.Notify(ctx, method, args, 1); err != nil {
				logError(ctx, "Error calling "+clientApi.Host+": "+err.Error())
			}
		}
	}
}

func enabledServers(ctx context.Context) ([]Server, bool) {
	servers := []Server{}
	cluster_servers := pfconfigdriver.AllClusterServers{}
	pfconfigdriver.FetchDecodeSocketCache(ctx, &cluster_servers)
	if len(servers) == 0 {
		return nil, false
	}
	for _, s := range cluster_servers.Element {
		server := Server{Host: s.Host, ManagementIp: s.ManagementIp}
		if !server.IsDisabled() {
			servers = append(servers, server)
		}
	}

	return servers, true
}
