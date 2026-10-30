package clientapi

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
)

// Package install from the admin interface: like the upgrade, the client
// cannot run apt itself (it lives inside the container), so it drops a
// trigger file in the conf dir shared with the host; the
// packetfence-pfconnector-install.path systemd unit on the host picks it up
// and apt-installs the packages. The allowlist below is enforced here, in
// the cloud API and in the host script, and apt only accepts packages signed
// by the PacketFence archive keyring.

// installablePackages are the PacketFence packages the admin may add to a
// connector host: the NTLM authentication services needed when an Active
// Directory domain is behind the connector (the join package pulls the api).
var installablePackages = []string{"packetfence-ntlm-auth-api-remote", "packetfence-ntlm-auth-join-remote"}

var (
	installTriggerFile = sharedutils.EnvOrDefault("PFCONNECTOR_INSTALL_TRIGGER_FILE", "/usr/local/pf/conf/install_requested")
	installStateFile   = sharedutils.EnvOrDefault("PFCONNECTOR_INSTALL_STATE_FILE", "/usr/local/pf/conf/install_state")
	// hostDpkgStatus is the host's dpkg status file, inside the /var/lib/dpkg
	// directory bind-mounted read-only by the docker wrapper (the directory,
	// because dpkg replaces the file on every change) so the client can
	// report what is installed.
	hostDpkgStatus = sharedutils.EnvOrDefault("PFCONNECTOR_HOST_DPKG_STATUS", "/usr/local/pf/var/host/dpkg/status")
	// ntlmJoinRemoteAddr is where the ntlm-join-remote service listens on the
	// host (containers/ntlm-join-remote docker wrapper, -p 100.64.0.1:23000).
	ntlmJoinRemoteAddr = sharedutils.EnvOrDefault("PFCONNECTOR_NTLM_JOIN_REMOTE_ADDR", "100.64.0.1:23000")
)

// HostPackage is the install state of one installable package on the host.
type HostPackage struct {
	Name      string `json:"name"`
	Installed bool   `json:"installed"`
	Version   string `json:"version,omitempty"`
}

// HostPackages is reported in /api/v1/system/info as "host_packages".
type HostPackages struct {
	Packages []HostPackage `json:"packages"`
	// Available is false when the host's dpkg database is not mounted (older
	// wrapper): the state is then unknown and the UI says so.
	Available bool `json:"available"`
	// NtlmJoinRemoteListening is true when the ntlm-join-remote service
	// accepts connections on the host, i.e. the packages are installed and
	// running.
	NtlmJoinRemoteListening bool `json:"ntlm_join_remote_listening"`
	// InstallState is the last line written by the host install script
	// ("installing: ...", "done: ...", "failed: ..."), empty when never run.
	InstallState string `json:"install_state,omitempty"`
}

// hostPackages reads the installable packages' state from the host dpkg
// database and probes the ntlm-join-remote listener.
func hostPackages() HostPackages {
	out := HostPackages{Packages: []HostPackage{}}
	installed := installedPackages(hostDpkgStatus)
	out.Available = installed != nil
	for _, name := range installablePackages {
		hp := HostPackage{Name: name}
		if v, ok := installed[name]; ok {
			hp.Installed, hp.Version = true, v
		}
		out.Packages = append(out.Packages, hp)
	}
	if conn, err := net.DialTimeout("tcp", ntlmJoinRemoteAddr, 300*time.Millisecond); err == nil {
		conn.Close()
		out.NtlmJoinRemoteListening = true
	}
	if data, err := os.ReadFile(installStateFile); err == nil {
		out.InstallState = strings.TrimSpace(string(data))
	}
	return out
}

// installedPackages parses a dpkg status file into name -> version for the
// packages in state "installed". Returns nil when the file is unreadable.
func installedPackages(path string) map[string]string {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	result := map[string]string{}
	var name, version string
	installedState := false
	flush := func() {
		if name != "" && installedState {
			result[name] = version
		}
		name, version, installedState = "", "", false
	}
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		switch {
		case line == "":
			flush()
		case strings.HasPrefix(line, "Package: "):
			name = strings.TrimSpace(strings.TrimPrefix(line, "Package: "))
		case strings.HasPrefix(line, "Version: "):
			version = strings.TrimSpace(strings.TrimPrefix(line, "Version: "))
		case strings.HasPrefix(line, "Status: "):
			installedState = strings.HasSuffix(strings.TrimSpace(line), " installed")
		}
	}
	flush()
	return result
}

// systemInstall validates the requested packages against the allowlist and
// hands them to the host through the trigger file. The install itself is
// asynchronous: the host logs to conf/install.log and writes conf/install_state,
// which system info reports along with the dpkg state.
func systemInstall(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			Packages []string `json:"packages"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid request body", http.StatusBadRequest)
			return
		}
		packages := []string{}
		for _, p := range req.Packages {
			p = strings.TrimSpace(p)
			allowed := false
			for _, a := range installablePackages {
				if p == a {
					allowed = true
				}
			}
			if !allowed {
				http.Error(w, fmt.Sprintf("Package %q cannot be installed from here", p), http.StatusBadRequest)
				return
			}
			packages = append(packages, p)
		}
		if len(packages) == 0 {
			http.Error(w, "No package requested", http.StatusBadRequest)
			return
		}
		sort.Strings(packages)

		// Write-then-rename so the host's path unit only ever sees a
		// complete trigger file.
		tmp := filepath.Join(filepath.Dir(installTriggerFile), ".install_requested.tmp")
		if err := os.WriteFile(tmp, []byte(strings.Join(packages, " ")+"\n"), 0600); err != nil {
			log.LoggerWContext(api.ctx).Error(fmt.Sprintf("Failed to write install trigger: %v", err))
			http.Error(w, "Failed to write the install trigger", http.StatusInternalServerError)
			return
		}
		if err := os.Rename(tmp, installTriggerFile); err != nil {
			log.LoggerWContext(api.ctx).Error(fmt.Sprintf("Failed to publish install trigger: %v", err))
			http.Error(w, "Failed to publish the install trigger", http.StatusInternalServerError)
			return
		}
		// Reflect the request immediately; the host overwrites it as it goes.
		os.WriteFile(installStateFile, []byte("requested: "+strings.Join(packages, " ")+"\n"), 0644)

		log.LoggerWContext(api.ctx).Info(fmt.Sprintf("Install of %s requested through the pfconnector-client API", strings.Join(packages, ", ")))
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]interface{}{"message": "Install scheduled", "packages": packages})
	})
}
