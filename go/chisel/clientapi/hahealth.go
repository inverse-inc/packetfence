package clientapi

import (
	"context"
	"os"
	"os/exec"
	"sync/atomic"
	"time"

	"github.com/inverse-inc/go-utils/sharedutils"
)

// HA: give the VIP away when the local FreeRADIUS is broken.
//
// keepalived's track script (chk_radiusd, weight -20) lowers the master's
// advertised priority when FreeRADIUS stops answering, but every host runs
// with nopreempt, so a backup never takes over on a lower-priority
// advertisement: only the master's disappearance moves the VIP. The weight
// still matters for the election that follows, it just cannot start one.
//
// So the client runs the same check itself on every host. A master whose
// check fails haHealthFall times in a row yields the VIP (yieldVIP, as for
// "Make active") provided a standby host reported alive with a working
// FreeRADIUS in its heartbeat; yielding to nobody, or to a host in the same
// state, would only add an outage. Standbys report their own check result in
// the heartbeat (radius_ok) for that decision and for the admin UI.

var (
	// haHealthCheck is the check script (exit 0 = healthy); the same one
	// keepalived tracks. Missing script (outside the container) = unknown =
	// never yield.
	haHealthCheck = sharedutils.EnvOrDefault("PFCONNECTOR_HA_CHECK", "/usr/local/pf/sbin/ha-check.sh")
	// haHealthInterval/haHealthFall mirror the vrrp_script interval/fall.
	haHealthInterval = 2 * time.Second
	haHealthFall     = 3
	// haHealthYieldCooldown: after yielding for health, do not yield again
	// for this long (the host is backup meanwhile anyway; this covers the
	// case where it wins the VIP back because the others were worse).
	haHealthYieldCooldown = 60 * time.Second
	// haHealthUnknown: the check could not run (script missing).
	haHealthUnknown = true
)

// radiusHealthy is the cached result of the last check (1 = healthy). Starts
// healthy so a host is not written off before its first check.
var radiusHealthy atomic.Int32

func init() { radiusHealthy.Store(1) }

// RadiusHealthy reports the last check result.
func RadiusHealthy() bool { return radiusHealthy.Load() == 1 }

// runHealthCheck executes the check script once.
func runHealthCheck(ctx context.Context) (healthy bool, known bool) {
	if _, err := os.Stat(haHealthCheck); err != nil {
		return true, false
	}
	cctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	err := exec.CommandContext(cctx, haHealthCheck).Run()
	return err == nil, true
}

// MonitorRadiusHealth runs the check every haHealthInterval until ctx is done,
// keeps RadiusHealthy up to date and makes a master with a broken FreeRADIUS
// yield the VIP to a healthy standby. Started once per HA client.
func MonitorRadiusHealth(ctx context.Context, logf func(string, ...interface{})) {
	ticker := time.NewTicker(haHealthInterval)
	defer ticker.Stop()
	failures := 0
	var lastYield time.Time
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
		healthy, known := runHealthCheck(ctx)
		if !known {
			radiusHealthy.Store(1)
			continue
		}
		if healthy {
			if failures >= haHealthFall {
				logf("HA: local FreeRADIUS is answering again")
			}
			failures = 0
			radiusHealthy.Store(1)
			continue
		}
		failures++
		if failures < haHealthFall {
			continue
		}
		radiusHealthy.Store(0)
		if failures == haHealthFall {
			logf("HA: local FreeRADIUS is not answering (%d consecutive failed checks)", failures)
		}
		status := HAStatusSnapshot()
		if status == nil || status.State != "master" || time.Since(lastYield) < haHealthYieldCooldown {
			continue
		}
		var target *HAPeer
		for i := range status.Peers {
			if status.Peers[i].Alive && status.Peers[i].RadiusOK {
				target = &status.Peers[i]
				break
			}
		}
		if target == nil {
			if failures == haHealthFall {
				logf("HA: keeping the VIP %s: no standby host with a working FreeRADIUS is reporting", status.VIP)
			}
			continue
		}
		logf("HA: local FreeRADIUS is down and %s (%s) is healthy, yielding the VIP %s", target.Hostname, target.Address, status.VIP)
		lastYield = time.Now()
		yieldVIP(logf)
	}
}
