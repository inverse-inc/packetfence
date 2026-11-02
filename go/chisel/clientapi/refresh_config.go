package clientapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
)

// Configuration refresh on request: the pfconnector server asks for it
// (POST /api/v1/system/refresh-config) when a switch or a connector was saved
// in PacketFence, so the RADIUS clients this host renders from the switches
// behind the connector (sync-radius-nas.sh) follow without a restart of the
// connector. The script re-runs every cloud sync oneshot and restarts only
// the services whose files changed, so a request that changes nothing costs
// a few API calls. Requests are coalesced: one run at a time, and a request
// received during a run queues exactly one more, so a change arriving while
// the scripts run is never missed.

// RefreshConfigScript is ha-refresh-config.sh in the connector-remote
// container; absent outside of it.
var RefreshConfigScript = sharedutils.EnvOrDefault("PFCONNECTOR_REFRESH_CONFIG_SCRIPT", "/usr/local/pf/sbin/ha-refresh-config.sh")

// RunRefreshConfigScript runs the refresh script with extra environment
// entries and arguments, and returns the lines it printed (one per change,
// with the timestamp the script stamps for keepalived.log stripped) and its
// error.
func RunRefreshConfigScript(ctx context.Context, env []string, args ...string) ([]string, error) {
	cmd := exec.CommandContext(ctx, RefreshConfigScript, args...)
	cmd.Env = append(os.Environ(), env...)
	out, err := cmd.CombinedOutput()
	lines := []string{}
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if len(line) > 20 {
			if _, perr := time.Parse("2006/01/02 15:04:05", line[:19]); perr == nil {
				line = line[20:]
			}
		}
		if line != "" {
			lines = append(lines, line)
		}
	}
	return lines, err
}

// refreshConfigRunner serializes the runs of a function and coalesces the
// requests received while it runs into one more run.
type refreshConfigRunner struct {
	mu      sync.Mutex
	running bool
	pending bool
	run     func()
}

func newRefreshConfigRunner(run func()) *refreshConfigRunner {
	return &refreshConfigRunner{run: run}
}

// Trigger requests a run. It returns true when a run was started, false when
// one is in progress and another was queued behind it (or already was).
func (r *refreshConfigRunner) Trigger() bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.running {
		r.pending = true
		return false
	}
	r.running = true
	go r.loop()
	return true
}

func (r *refreshConfigRunner) loop() {
	for {
		r.run()
		r.mu.Lock()
		if r.pending {
			r.pending = false
			r.mu.Unlock()
			continue
		}
		r.running = false
		r.mu.Unlock()
		return
	}
}

// refreshConfig runs the refresh script for the API handler.
var refreshConfig = newRefreshConfigRunner(func() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	lines, err := RunRefreshConfigScript(ctx, nil)
	for _, line := range lines {
		log.LoggerWContext(ctx).Info("refresh-config: " + line)
	}
	if err != nil {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("refresh-config: %s: %s", RefreshConfigScript, err))
	}
})

// systemRefreshConfig schedules a configuration refresh. 202: the scripts
// run in the background; 501 outside the connector-remote container.
func systemRefreshConfig(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		if _, err := os.Stat(RefreshConfigScript); err != nil {
			http.Error(w, "Configuration refresh is not available on this connector", http.StatusNotImplemented)
			return
		}
		started := refreshConfig.Trigger()
		log.LoggerWContext(api.ctx).Info(fmt.Sprintf("Configuration refresh requested through the pfconnector-client API (started: %t)", started))
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusAccepted)
		json.NewEncoder(w).Encode(map[string]interface{}{"message": "Configuration refresh scheduled", "started": started})
	})
}
