package clientapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/inverse-inc/go-utils/log"
)

// Services of the connector-remote container itself, restarted from the
// admin interface: FreeRADIUS (the RADIUS server the equipment of the site
// talks to, proxied to PacketFence through the tunnel) and connector-cache
// (the RADIUS cache). Both are s6-overlay longruns supervised under
// /run/service in this very container, so unlike the NTLM units of the host
// (host_services.go) they are reached directly with s6-svc, synchronously:
// the state is read with s6-svstat and reported in /api/v1/system/info as
// "container_services".

var (
	// s6ServiceDir holds one directory per supervised service.
	s6ServiceDir = "/run/service"
	// s6SvstatBinary and s6SvcCommand are s6's status and control tools
	// (s6-overlay v3 installs them under /command). Variables for the tests.
	s6SvstatBinary = "/command/s6-svstat"
	s6SvcCommand   = s6svcBinary
)

// containerServiceDefs are the services the admin may restart, with the
// description shown in the admin interface.
var containerServiceDefs = []ContainerService{
	{Name: "radiusd-auth", Description: "FreeRADIUS: the RADIUS server of the site, proxied to PacketFence through the tunnel"},
	{Name: "connector-cache", Description: "RADIUS cache: the RADIUS authorizations and credentials replayed when PacketFence is unreachable, and the rate limiter"},
}

// containerServiceAllowed tells whether name is a service the admin may act on.
func containerServiceAllowed(name string) bool {
	for _, svc := range containerServiceDefs {
		if svc.Name == name {
			return true
		}
	}
	return false
}

// ContainerService is the state of one supervised service of the container.
type ContainerService struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	// Up is whether the process is running; WantedUp whether the supervisor
	// wants it running (false after a stop, true while it restarts).
	Up       bool `json:"up"`
	WantedUp bool `json:"wanted_up"`
	PID      int  `json:"pid,omitempty"`
	// SinceSeconds is how long the service has been in its current state
	// (up or down).
	SinceSeconds int64 `json:"since_seconds"`
	// ExitCode and Signal describe how the last process ended; only set when
	// the service is down.
	ExitCode *int   `json:"exit_code,omitempty"`
	Signal   string `json:"signal,omitempty"`
	// Error is set when the state could not be read (the service is not
	// supervised in this container).
	Error string `json:"error,omitempty"`
}

// ContainerServices is reported in /api/v1/system/info as "container_services".
type ContainerServices struct {
	Services []ContainerService `json:"services"`
}

// s6SvstatFields is the -o field list read from s6-svstat, in this order.
const s6SvstatFields = "up,wantedup,pid,exitcode,signal,updownfor"

// containerServices reads the state of every managed service; nil when
// s6-svstat is not there (the API running outside the container, tests).
func containerServices() *ContainerServices {
	if _, err := os.Stat(s6SvstatBinary); err != nil {
		return nil
	}
	out := &ContainerServices{Services: make([]ContainerService, 0, len(containerServiceDefs))}
	for _, def := range containerServiceDefs {
		svc := def
		raw, err := exec.Command(s6SvstatBinary, "-o", s6SvstatFields, filepath.Join(s6ServiceDir, def.Name)).Output()
		if err != nil {
			svc.Error = "the service is not supervised"
			if exitErr, ok := err.(*exec.ExitError); ok && len(exitErr.Stderr) > 0 {
				svc.Error = strings.TrimSpace(string(exitErr.Stderr))
			}
		} else if err := parseS6Svstat(strings.TrimSpace(string(raw)), &svc); err != nil {
			svc.Error = err.Error()
		}
		out.Services = append(out.Services, svc)
	}
	return out
}

// parseS6Svstat fills svc from one line of s6-svstat -o s6SvstatFields:
// "true true 374667 -1 NA 72656" (exit code -1 and signal NA while up).
func parseS6Svstat(line string, svc *ContainerService) error {
	fields := strings.Fields(line)
	if len(fields) != 6 {
		return fmt.Errorf("unexpected s6-svstat output %q", line)
	}
	svc.Up = fields[0] == "true"
	svc.WantedUp = fields[1] == "true"
	if pid, err := strconv.Atoi(fields[2]); err == nil && svc.Up {
		svc.PID = pid
	}
	if !svc.Up {
		if code, err := strconv.Atoi(fields[3]); err == nil && code >= 0 {
			svc.ExitCode = &code
		}
		if fields[4] != "NA" {
			svc.Signal = fields[4]
		}
	}
	since, err := strconv.ParseInt(fields[5], 10, 64)
	if err != nil {
		return fmt.Errorf("unexpected s6-svstat duration %q", fields[5])
	}
	svc.SinceSeconds = since
	return nil
}

// containerServicesStatus serves the state of the managed services (the same
// "container_services" object as system info).
func containerServicesStatus(_ *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		state := containerServices()
		if state == nil {
			http.Error(w, "The services of the container are not supervised here", http.StatusNotFound)
			return
		}
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(state)
	})
}

// containerServiceRestart restarts one managed service in place: s6-svc -r
// (SIGTERM, the supervisor starts it again) when it runs, s6-svc -u when it
// is down. Synchronous and local, so the answer is a 200.
func containerServiceRestart(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var srv Service
		if err := json.NewDecoder(r.Body).Decode(&srv); err != nil {
			http.Error(w, "Invalid request body", http.StatusBadRequest)
			return
		}
		if srv.Name == "" {
			http.Error(w, "Service name is required", http.StatusBadRequest)
			return
		}
		if !containerServiceAllowed(srv.Name) {
			http.Error(w, fmt.Sprintf("Service %s is not a service of the connector", srv.Name), http.StatusForbidden)
			return
		}
		dir := filepath.Join(s6ServiceDir, srv.Name)
		if _, err := os.Stat(dir); err != nil {
			http.Error(w, fmt.Sprintf("Service %s is not supervised in this container", srv.Name), http.StatusNotFound)
			return
		}
		flag := "-u"
		if out, err := exec.Command(s6SvstatBinary, "-o", "up", dir).Output(); err == nil && strings.TrimSpace(string(out)) == "true" {
			flag = "-r"
		}
		if out, err := exec.Command(s6SvcCommand, flag, dir).CombinedOutput(); err != nil {
			log.LoggerWContext(api.ctx).Error(fmt.Sprintf("Failed to restart %s (s6-svc %s): %v: %s", srv.Name, flag, err, strings.TrimSpace(string(out))))
			http.Error(w, fmt.Sprintf("Failed to restart %s", srv.Name), http.StatusInternalServerError)
			return
		}
		log.LoggerWContext(api.ctx).Info(fmt.Sprintf("Restart of %s requested through the pfconnector-client API (s6-svc %s)", srv.Name, flag))
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{
			"message": fmt.Sprintf("%s restarted", srv.Name),
			"service": srv.Name,
			"action":  "restart",
		})
	})
}
