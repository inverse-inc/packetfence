package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/coreos/go-systemd/daemon"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

const (
	configRefreshInterval = 10 * time.Second
	shutdownTimeout       = 10 * time.Second
)

func main() {
	// Setup graceful shutdown
	rootCtx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle interruptions
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		cancel()
	}()

	// Initialize logging
	log.SetProcessName("pfudpproxy")
	ctx := log.LoggerNewContext(rootCtx)

	// Check if cluster mode is enabled
	clusterSummary := pfconfigdriver.GetClusterSummary(ctx)
	if clusterSummary.ClusterEnabled != 1 {
		log.LoggerWContext(ctx).Info("Cluster mode is not enabled, exiting")
		return
	}

	// Load initial configuration
	config, err := LoadConfig(ctx)
	if err != nil {
		log.LoggerWContext(ctx).Crit("Failed to load configuration: " + err.Error())
		return
	}

	if config.VIPAddress == "" {
		log.LoggerWContext(ctx).Crit("No VIP address configured, exiting")
		return
	}

	if len(config.Backends) == 0 {
		log.LoggerWContext(ctx).Crit("No backends configured, exiting")
		return
	}

	log.LoggerWContext(ctx).Info("Starting pfudpproxy with VIP: " + config.VIPAddress)

	// Create load balancer
	lb := NewLoadBalancer(config.Backends)

	// Create and start health checker
	healthChecker := NewHealthChecker(config, lb)
	go healthChecker.Start(ctx)

	// Create and start UDP proxy
	proxy := NewUDPProxy(config, lb)
	go proxy.Start(ctx)

	// Notify systemd we're ready
	daemon.SdNotify(false, "READY=1")

	// Setup systemd watchdog
	go setupSystemdWatchdog(ctx)

	// Periodically refresh configuration
	go refreshConfigLoop(ctx, proxy, lb, healthChecker)

	// Wait for shutdown signal
	<-rootCtx.Done()

	log.LoggerWContext(ctx).Info("Shutting down pfudpproxy...")

	// Graceful shutdown
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), shutdownTimeout)
	defer shutdownCancel()

	proxy.Stop(shutdownCtx)

	log.LoggerWContext(ctx).Info("pfudpproxy stopped")
}

// setupSystemdWatchdog configures systemd watchdog reporting
func setupSystemdWatchdog(ctx context.Context) {
	interval, err := daemon.SdWatchdogEnabled(false)
	if err != nil || interval == 0 {
		return
	}

	ticker := time.NewTicker(interval / 3)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			daemon.SdNotify(false, "WATCHDOG=1")
		}
	}
}

// refreshConfigLoop periodically refreshes the configuration
func refreshConfigLoop(ctx context.Context, proxy *UDPProxy, lb *LoadBalancer, hc *HealthChecker) {
	ticker := time.NewTicker(configRefreshInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			pfconfigdriver.PfConfigStorePool.Refresh(ctx)

			// Reload configuration
			config, err := LoadConfig(ctx)
			if err != nil {
				log.LoggerWContext(ctx).Error("Failed to reload configuration: " + err.Error())
				continue
			}

			// Update backends in load balancer
			lb.UpdateBackends(config.Backends)

			// Update proxy configuration if VIP changed
			proxy.UpdateConfig(ctx, config)

			// Update health checker (port, timeout, interval, etc.)
			hc.UpdateConfig(config)
		}
	}
}
