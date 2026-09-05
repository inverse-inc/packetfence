package clientapi

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"sort"
	"strings"
	"syscall"
	"time"

	"github.com/inverse-inc/go-utils/log"
	chshare "github.com/inverse-inc/packetfence/go/chisel/share"
	"github.com/inverse-inc/packetfence/go/chisel/share/dhcprelay"
	"github.com/inverse-inc/packetfence/go/chisel/share/dnsresponder"
	"github.com/inverse-inc/packetfence/go/chisel/share/sitenetwork"
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
	// SiteNetwork is the result of the last VLAN interface / static route
	// reconcile pass (see chisel/share/sitenetwork). Omitted until the first
	// pass ran; the admin UI shows it in the connector's Networking tab.
	SiteNetwork *sitenetwork.Status `json:"site_network,omitempty"`
	// DhcpRelay lists the DHCP-over-HTTPS relay listeners (one per VLAN
	// interface flagged dhcp_relay) with their counters.
	DhcpRelay []dhcprelay.Status `json:"dhcp_relay,omitempty"`
	// DnsServer lists the captive DNS responders (one per VLAN interface
	// flagged dns_server) with their query counters.
	DnsServer []dnsresponder.Status `json:"dns_server,omitempty"`
	// HostInterfaces lists the network interfaces of the connector host (the
	// container runs with --network=host), loopback excluded. The admin UI
	// offers them as choices for the parent of a VLAN interface and for the
	// interface of a static route.
	HostInterfaces []HostInterface `json:"host_interfaces,omitempty"`
}

// HostInterface is one network interface of the connector host.
type HostInterface struct {
	Name      string   `json:"name"`
	Up        bool     `json:"up"`
	Addresses []string `json:"addresses"` // CIDR notation, IPv4 and IPv6
	// Main is set on the interface holding the IPv4 default route: the one the
	// connector reaches PacketFence through and the natural parent for the
	// site VLANs. The admin UI lists it first and preselects it.
	Main bool `json:"main"`
}

// hostInterfaces returns the host's interfaces, main one first then sorted by
// name, loopback excluded. Errors are swallowed: the field is informational.
func hostInterfaces() []HostInterface {
	ifaces, err := net.Interfaces()
	if err != nil {
		return nil
	}
	main := defaultRouteInterface()
	out := []HostInterface{}
	for _, iface := range ifaces {
		if iface.Flags&net.FlagLoopback != 0 {
			continue
		}
		hi := HostInterface{Name: iface.Name, Up: iface.Flags&net.FlagUp != 0, Addresses: []string{}, Main: iface.Name == main}
		if addrs, err := iface.Addrs(); err == nil {
			for _, a := range addrs {
				hi.Addresses = append(hi.Addresses, a.String())
			}
		}
		out = append(out, hi)
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Main != out[j].Main {
			return out[i].Main
		}
		return out[i].Name < out[j].Name
	})
	return out
}

// defaultRouteInterface returns the name of the interface holding the IPv4
// default route (/proc/net/route, destination 0.0.0.0), or "" when none.
func defaultRouteInterface() string {
	file, err := os.Open("/proc/net/route")
	if err != nil {
		return ""
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		fields := strings.Fields(scanner.Text())
		if len(fields) >= 2 && fields[1] == "00000000" {
			return fields[0]
		}
	}
	return ""
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
			SiteNetwork:     sitenetwork.LastStatus(),
			DhcpRelay:       dhcprelay.LastStatus(),
			DnsServer:       dnsresponder.LastStatus(),
			HostInterfaces:  hostInterfaces(),
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
