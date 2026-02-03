package main

import (
	"context"
	"fmt"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// Default configuration values
const (
	DefaultHealthCheckPort     = 4723
	DefaultHealthCheckPath     = "/"
	DefaultHealthCheckInterval = 5 * time.Second
	DefaultHealthCheckTimeout  = 10 * time.Second
	DefaultExpectedStatusCode  = 404

	PortNetFlow = 2055
	PortSFlow   = 6343
)

// ProxyConfig holds the configuration for the UDP proxy
type ProxyConfig struct {
	VIPAddress          string
	Ports               []int
	Backends            []*Backend
	HealthCheckPort     int
	HealthCheckPath     string
	HealthCheckInterval time.Duration
	HealthCheckTimeout  time.Duration
	ExpectedStatusCode  int
}

// Backend represents a cluster member that can receive forwarded packets
type Backend struct {
	Host         string
	ManagementIP string
	Healthy      bool
	LastCheck    time.Time
}

// getHealthCheckPort returns the health check port from FingerbankSettingsCollector or default
func getHealthCheckPort(ctx context.Context) int {
	collector := pfconfigdriver.GetType[pfconfigdriver.FingerbankSettingsCollector](ctx)
	if port, err := collector.Port.Int64(); err == nil && port > 0 && port < 65536 {
		return int(port)
	}
	return DefaultHealthCheckPort
}

// LoadConfig loads the proxy configuration from pfconfig
func LoadConfig(ctx context.Context) (*ProxyConfig, error) {
	config := &ProxyConfig{
		Ports:               []int{PortNetFlow, PortSFlow},
		HealthCheckPort:     getHealthCheckPort(ctx),
		HealthCheckPath:     DefaultHealthCheckPath,
		HealthCheckInterval: DefaultHealthCheckInterval,
		HealthCheckTimeout:  DefaultHealthCheckTimeout,
		ExpectedStatusCode:  DefaultExpectedStatusCode,
	}

	// Load VIP address from management network configuration
	vip, err := loadVIPAddress(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to load VIP address: %w", err)
	}
	config.VIPAddress = vip

	// Load cluster members as backends
	backends, err := loadBackends(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to load backends: %w", err)
	}
	config.Backends = backends

	return config, nil
}

// loadVIPAddress loads the VIP address from the cluster configuration
func loadVIPAddress(ctx context.Context) (string, error) {
	var mgmtNet pfconfigdriver.ManagementNetwork
	pfconfigdriver.FetchDecodeSocketCache(ctx, &mgmtNet)

	var keyConfCluster pfconfigdriver.NetInterface
	keyConfCluster.PfconfigNS = "config::Pf(CLUSTER," + pfconfigdriver.FindClusterName(ctx) + ")"
	keyConfCluster.PfconfigHashNS = "interface " + mgmtNet.Int
	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfCluster)

	if keyConfCluster.Ip == "" {
		log.LoggerWContext(ctx).Warn("No VIP configured in cluster config for interface " + mgmtNet.Int)
		return "", nil
	}

	log.LoggerWContext(ctx).Debug("Loaded VIP address from cluster config: " + keyConfCluster.Ip)
	return keyConfCluster.Ip, nil
}

// loadBackends loads cluster members from pfconfig
func loadBackends(ctx context.Context) ([]*Backend, error) {
	var clusterServers pfconfigdriver.AllClusterServers
	pfconfigdriver.FetchDecodeSocketCache(ctx, &clusterServers)

	backends := make([]*Backend, 0, len(clusterServers.Element))
	for _, server := range clusterServers.Element {
		if server.ManagementIp == "" {
			log.LoggerWContext(ctx).Warn("Cluster server " + server.Host + " has no management IP, skipping")
			continue
		}

		backend := &Backend{
			Host:         server.Host,
			ManagementIP: server.ManagementIp,
			Healthy:      false, // Will be updated by health checker
			LastCheck:    time.Time{},
		}
		backends = append(backends, backend)
		log.LoggerWContext(ctx).Debug("Added backend: " + server.Host + " (" + server.ManagementIp + ")")
	}

	if len(backends) == 0 {
		return nil, fmt.Errorf("no valid cluster servers found")
	}

	return backends, nil
}
