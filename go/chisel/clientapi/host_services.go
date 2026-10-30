package clientapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
)

// Management of the NTLM authentication services from the admin interface.
//
// They are systemd units of the connector host (docker containers started by
// packetfence-ntlm-auth-api-remote.service and friends), out of reach of this
// container, which has no access to the host's systemd. Like the package
// install, an action is a trigger file dropped in the conf dir shared with
// the host; packetfence-pfconnector-services.path on the host picks it up,
// its script runs systemctl (against its own allowlist) and writes the state
// of every managed unit back to conf/services_state. That state is reported
// in /api/v1/system/info as "host_services"; when it is older than
// servicesStateMaxAge a "status" refresh is requested, so the admin UI's
// regular polling keeps it current without a timer on the host.

var (
	servicesTriggerFile = sharedutils.EnvOrDefault("PFCONNECTOR_SERVICES_TRIGGER_FILE", "/usr/local/pf/conf/services_requested")
	servicesStateFile   = sharedutils.EnvOrDefault("PFCONNECTOR_SERVICES_STATE_FILE", "/usr/local/pf/conf/services_state")
	// servicesStateMaxAge is how old the reported state may be before a
	// refresh is requested from the host.
	servicesStateMaxAge = 20 * time.Second
	// servicesRefreshMinInterval keeps concurrent status polls from flooding
	// the host with refresh requests (the host rate-limits them too).
	servicesRefreshMinInterval = 5 * time.Second

	servicesRefreshMu   sync.Mutex
	servicesRefreshLast time.Time
)

// hostServiceActions are the actions the admin may request on a unit.
// "reload" applies the domain list of PacketFence to the NTLM API controller
// (new domains started, removed ones stopped, the others untouched) and is
// only valid on hostServiceController.
var hostServiceActions = map[string]bool{"start": true, "stop": true, "restart": true, "enable": true, "disable": true, "reload": true}

// hostServiceController is the NTLM API controller unit, which starts one
// instance per domain.
const hostServiceController = "packetfence-ntlm-auth-api-remote.service"

// fixedHostServices are the NTLM authentication units of the host.
var fixedHostServices = []string{
	hostServiceController,
	"packetfence-ntlm-auth-join-remote.service",
}

// domainHostServiceRe matches the per-domain instances of the NTLM API
// (one per domain behind the connector, named after the domain's identifier
// in PacketFence). The host script enforces the same pattern.
var domainHostServiceRe = regexp.MustCompile(`^packetfence-ntlm-auth-api-domain-remote@[A-Za-z0-9][A-Za-z0-9._-]{0,63}\.service$`)

// hostServiceAllowed tells whether name is a unit the admin may act on.
func hostServiceAllowed(name string) bool {
	for _, unit := range fixedHostServices {
		if name == unit {
			return true
		}
	}
	return domainHostServiceRe.MatchString(name)
}

// HostService is the state of one managed unit, as written by the host script.
type HostService struct {
	Name          string `json:"name"`
	Installed     bool   `json:"installed"`
	ActiveState   string `json:"active_state"`
	SubState      string `json:"sub_state"`
	UnitFileState string `json:"unit_file_state,omitempty"`
	Restarts      int    `json:"restarts"`
	Since         string `json:"since,omitempty"`
	Description   string `json:"description,omitempty"`
}

// HostServiceAction is the outcome of the last start/stop/restart run by the host.
type HostServiceAction struct {
	Action  string `json:"action"`
	Unit    string `json:"unit"`
	At      string `json:"at"`
	Result  string `json:"result"`
	Message string `json:"message,omitempty"`
}

// HostServices is reported in /api/v1/system/info as "host_services".
type HostServices struct {
	// Available is false when the host never wrote a state: a connector
	// package without the services path unit, or the first poll since boot
	// (a refresh is then requested and the next poll has it).
	Available bool `json:"available"`
	// Updated is when the host wrote the state (RFC 3339, UTC).
	Updated string `json:"updated,omitempty"`
	// Stale is true when the state is older than servicesStateMaxAge and a
	// refresh has been requested.
	Stale      bool               `json:"stale"`
	LastAction *HostServiceAction `json:"last_action,omitempty"`
	Services   []HostService      `json:"services"`
}

// hostServices reads the state written by the host and requests a refresh
// when it is missing or stale.
func hostServices() HostServices {
	out := HostServices{Services: []HostService{}}
	data, err := os.ReadFile(servicesStateFile)
	if err != nil {
		requestHostServicesRefresh()
		return out
	}
	var state struct {
		Updated    string             `json:"updated"`
		LastAction *HostServiceAction `json:"last_action"`
		Services   []HostService      `json:"services"`
	}
	if err := json.Unmarshal(data, &state); err != nil {
		requestHostServicesRefresh()
		return out
	}
	out.Available = true
	out.Updated = state.Updated
	out.Services = state.Services
	if out.Services == nil {
		out.Services = []HostService{}
	}
	if state.LastAction != nil && state.LastAction.Action != "" {
		out.LastAction = state.LastAction
	}
	updated, err := time.Parse(time.RFC3339, state.Updated)
	if err != nil || time.Since(updated) > servicesStateMaxAge {
		out.Stale = true
		requestHostServicesRefresh()
	}
	return out
}

// requestHostServicesRefresh asks the host for a fresh state, unless a
// request was made recently or a trigger (an action, typically) is already
// waiting: a pending action must never be replaced by a status refresh.
func requestHostServicesRefresh() {
	servicesRefreshMu.Lock()
	defer servicesRefreshMu.Unlock()
	if time.Since(servicesRefreshLast) < servicesRefreshMinInterval {
		return
	}
	servicesRefreshLast = time.Now()
	tmp := filepath.Join(filepath.Dir(servicesTriggerFile), ".services_status.tmp")
	if err := os.WriteFile(tmp, []byte("status\n"), 0600); err != nil {
		return
	}
	// Link fails when the trigger exists: create-if-absent, atomically.
	if err := os.Link(tmp, servicesTriggerFile); err != nil && !os.IsExist(err) {
		log.LoggerWContext(context.Background()).Warn(fmt.Sprintf("Failed to request a refresh of the host services state: %v", err))
	}
	os.Remove(tmp)
}

// writeHostServiceTrigger publishes an action for the host: write then
// rename, so the host's path unit only ever sees a complete trigger file.
// An action replaces a pending status refresh (the host refreshes the state
// after every action anyway).
func writeHostServiceTrigger(action, unit string) error {
	tmp := filepath.Join(filepath.Dir(servicesTriggerFile), ".services_requested.tmp")
	if err := os.WriteFile(tmp, []byte(action+" "+unit+"\n"), 0600); err != nil {
		return fmt.Errorf("write: %w", err)
	}
	if err := os.Rename(tmp, servicesTriggerFile); err != nil {
		os.Remove(tmp)
		return fmt.Errorf("publish: %w", err)
	}
	return nil
}

// hostServicesStatus serves the state of the managed units (the same
// "host_services" object as system info).
func hostServicesStatus(_ *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(hostServices())
	})
}

// hostServiceAction requests a start, stop or restart of one managed unit
// from the host. The action is asynchronous: 202 means the request reached
// the host's trigger file; the unit's state follows in system info.
func hostServiceAction(api *API, action string) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !hostServiceActions[action] {
			http.Error(w, "Invalid action", http.StatusBadRequest)
			return
		}
		var srv Service
		if err := json.NewDecoder(r.Body).Decode(&srv); err != nil {
			http.Error(w, "Invalid request body", http.StatusBadRequest)
			return
		}
		if srv.Name == "" {
			http.Error(w, "Service name is required", http.StatusBadRequest)
			return
		}
		if !hostServiceAllowed(srv.Name) {
			http.Error(w, fmt.Sprintf("Service %s is not an NTLM authentication service of the connector host", srv.Name), http.StatusForbidden)
			return
		}
		if action == "reload" && srv.Name != hostServiceController {
			http.Error(w, fmt.Sprintf("Only %s reloads its domains", hostServiceController), http.StatusBadRequest)
			return
		}
		if err := writeHostServiceTrigger(action, srv.Name); err != nil {
			log.LoggerWContext(api.ctx).Error(fmt.Sprintf("Failed to request %s of %s on the host: %v", action, srv.Name, err))
			http.Error(w, "Failed to write the service request for the host", http.StatusInternalServerError)
			return
		}
		log.LoggerWContext(api.ctx).Info(fmt.Sprintf("%s of %s requested through the pfconnector-client API", action, srv.Name))
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusAccepted)
		json.NewEncoder(w).Encode(map[string]string{
			"message": fmt.Sprintf("%s of %s requested on the connector host", action, srv.Name),
			"service": srv.Name,
			"action":  action,
		})
	})
}
