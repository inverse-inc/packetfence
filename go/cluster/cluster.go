package cluster

import (
	"context"
	"errors"
	"os"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
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

func CallCluster(ctx context.Context, method string, args interface{}) bool {
	servers, cluster_mode := EnabledServers(ctx)
	if cluster_mode {
		clientApi := jsonrpc2.NewClientFromConfig(ctx)
		clientApi.Proto = "https"
		for _, member := range servers {
			clientApi.Host = member.ManagementIp
			if _, err := clientApi.Call(ctx, method, args); err != nil {
				log.LogError(ctx, "Error calling "+clientApi.Host+": "+err.Error())
			}
		}
	}

	return cluster_mode
}

func NotifyCluster(ctx context.Context, method string, args interface{}) bool {
	servers, cluster_mode := EnabledServers(ctx)
	if cluster_mode {
		clientApi := jsonrpc2.NewClientFromConfig(ctx)
		clientApi.Proto = "https"
		for _, member := range servers {
			clientApi.Host = member.ManagementIp
			if err := clientApi.Notify(ctx, method, args); err != nil {
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

func UnifiedAPICallCluster(ctx context.Context, method string, path string, createResponseStructPtr func(serverId string) interface{}) (errs map[string]error) {
	servers, cluster_mode := EnabledServers(ctx)
	if cluster_mode {
		for _, member := range servers {
			client := unifiedapiclient.NewFromConfig(ctx)
			client.Host = member.ManagementIp
			resp := createResponseStructPtr(member.Host)
			err := client.Call(ctx, method, path, resp)
			if err != nil {
				errs[member.Host] = err
			}
		}
	} else {
		errs["CLUSTER"] = errors.New("This is not a cluster...")
	}
	return errs
}
