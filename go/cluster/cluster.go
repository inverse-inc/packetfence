package cluster

import (
	"context"
	"os"

	"github.com/inverse-inc/go-utils/log"
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

func CallCluster(ctx context.Context, method string, args interface{}, tenant_id int) bool {
	servers, cluster_mode := EnabledServers(ctx)
	if cluster_mode {
		clientApi := jsonrpc2.NewClientFromConfig(ctx)
		clientApi.Proto = "https"
		for _, member := range servers {
			clientApi.Host = member.ManagementIp
			if _, err := clientApi.Call(ctx, method, args, tenant_id); err != nil {
				log.LogError(ctx, "Error calling "+clientApi.Host+": "+err.Error())
			}
		}
	}

	return cluster_mode
}

func NotifyCluster(ctx context.Context, method string, args interface{}, tenant_id int) bool {
	servers, cluster_mode := EnabledServers(ctx)
	if cluster_mode {
		clientApi := jsonrpc2.NewClientFromConfig(ctx)
		clientApi.Proto = "https"
		for _, member := range servers {
			clientApi.Host = member.ManagementIp
			if err := clientApi.Notify(ctx, method, args, tenant_id); err != nil {
				log.LogError(ctx, "Error calling "+clientApi.Host+": "+err.Error())
			}
		}
	}
	return cluster_mode
}

func EnabledServers(ctx context.Context) ([]Server, bool) {
	servers := []Server{}
	cluster_servers := pfconfigdriver.AllClusterServers{}
	pfconfigdriver.FetchDecodeSocketCache(ctx, &cluster_servers)
	if len(cluster_servers.Element) == 0 {
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
