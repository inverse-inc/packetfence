package clientapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"syscall"
	"time"

	"github.com/inverse-inc/go-utils/log"
	chshare "github.com/inverse-inc/packetfence/go/chisel/share"
	"github.com/shirou/gopsutil/v4/cpu"
	"github.com/shirou/gopsutil/v4/disk"
	"github.com/shirou/gopsutil/v4/host"
	"github.com/shirou/gopsutil/v4/load"
	"github.com/shirou/gopsutil/v4/mem"
)

// SystemInfo is the reply of /api/v1/system/info.
type SystemInfo struct {
	Hostname      string  `json:"hostname"`
	Version       string  `json:"version"`
	UptimeSeconds uint64  `json:"uptime_seconds"`
	Load1         float64 `json:"load1"`
	Load5         float64 `json:"load5"`
	Load15        float64 `json:"load15"`
	CPUCount      int     `json:"cpu_count"`
	CPUUsage      float64 `json:"cpu_usage_percent"`
	MemTotal      uint64  `json:"mem_total"`
	MemUsed       uint64  `json:"mem_used"`
	MemAvailable  uint64  `json:"mem_available"`
	MemUsage      float64 `json:"mem_usage_percent"`
	DiskTotal     uint64  `json:"disk_total"`
	DiskUsed      uint64  `json:"disk_used"`
	DiskUsage     float64 `json:"disk_usage_percent"`
	// TerminalEnabled/TerminalTOTP let the admin UI know whether the remote
	// terminal is available and whether opening it prompts for a TOTP code.
	// Informational only: enforcement happens in enableTerminal.
	TerminalEnabled bool `json:"terminal_enabled"`
	TerminalTOTP    bool `json:"terminal_totp"`
	// LogFiles lists the log allowlist keys that can be live-streamed from
	// this connector right now. The admin UI keys the "View Logs" button on
	// it; connectors predating the feature simply omit the field.
	LogFiles []string `json:"log_files,omitempty"`
}

// systemInfo reports resource usage of the box running the
// connector-remote. The container runs with --network=host and shares the
// host kernel, so loadavg/meminfo/cpu are host-wide values.
func systemInfo(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		info := SystemInfo{
			Version:         chshare.BuildVersion,
			TerminalEnabled: api.TerminalEnabled,
			TerminalTOTP:    api.TerminalEnabled && api.terminalTOTPRequired,
			LogFiles:        availableLogFiles(api),
		}
		info.Hostname, _ = os.Hostname()

		if uptime, err := host.Uptime(); err == nil {
			info.UptimeSeconds = uptime
		}
		if avg, err := load.Avg(); err == nil {
			info.Load1, info.Load5, info.Load15 = avg.Load1, avg.Load5, avg.Load15
		}
		if count, err := cpu.Counts(true); err == nil {
			info.CPUCount = count
		}
		if percents, err := cpu.Percent(time.Second, false); err == nil && len(percents) > 0 {
			info.CPUUsage = percents[0]
		}
		if vm, err := mem.VirtualMemory(); err == nil {
			info.MemTotal = vm.Total
			info.MemUsed = vm.Used
			info.MemAvailable = vm.Available
			info.MemUsage = vm.UsedPercent
		}
		if du, err := disk.Usage("/"); err == nil {
			info.DiskTotal = du.Total
			info.DiskUsed = du.Used
			info.DiskUsage = du.UsedPercent
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(info)
	})
}

// s6HaltPath is the s6-overlay v3 shutdown trigger. Running it cleanly stops
// every supervised service and exits the container; the host systemd unit
// (Restart=always) then brings the whole connector-remote back up.
const s6HaltPath = "/run/s6/basedir/bin/halt"

// systemRestart schedules a restart of the whole connector-remote container.
// The 200 reply is sent first; the shutdown fires shortly after so it can
// cross the tunnel before it collapses.
func systemRestart(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.LoggerWContext(api.ctx).Info("Restart requested through the pfconnector-client API")

		go func() {
			time.Sleep(2 * time.Second)
			if _, err := os.Stat(s6HaltPath); err == nil {
				if err := exec.Command(s6HaltPath).Run(); err == nil {
					return
				}
				log.LoggerWContext(api.ctx).Error(fmt.Sprintf("Failed to run %s, falling back to signaling PID 1", s6HaltPath))
			}
			// Fallback: SIGTERM to PID 1 (s6-svscan) also triggers a clean
			// container shutdown.
			if err := syscall.Kill(1, syscall.SIGTERM); err != nil {
				log.LoggerWContext(api.ctx).Error(fmt.Sprintf("Failed to signal PID 1: %v", err))
			}
		}()

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"message": "Restart scheduled"}`))
	})
}
