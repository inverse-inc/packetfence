package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/connector"
)

// connectorDetail mirrors the chisel server's /connector-detail reply.
type connectorDetail struct {
	ConnectorID       string                   `json:"connector_id"`
	Connected         bool                     `json:"connected"`
	RemoteIPs         []string                 `json:"remote_ips"`
	StaticConnections []map[string]interface{} `json:"static_connections"`
	BoundRemotes      []map[string]interface{} `json:"bound_remotes"`
}

// pfconnectorRemoteStatus aggregates everything the admin UI shows about one
// connector-remote: tunnel state and static ports (from the pfconnector
// server) plus live system stats (from the remote itself, over a dynreverse
// tunnel to its local API).
func (h APIHandler) pfconnectorRemoteStatus() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID := chi.URLParam(r, "connectorID")
		if connectorID == "" {
			http.Error(w, "PFconnector ID is required", http.StatusBadRequest)
			return
		}

		conn := connector.NewConnectorsContainer(h.ctx).Get(h.ctx, connectorID)
		if conn == nil {
			http.Error(w, "Unknown PFconnector ID", http.StatusNotFound)
			return
		}

		reply := struct {
			connectorDetail
			System           map[string]interface{} `json:"system"`
			CentralVersion   string                 `json:"central_version,omitempty"`
			UpgradeAvailable bool                   `json:"upgrade_available"`
			Errors           []string               `json:"errors,omitempty"`
		}{}
		reply.ConnectorID = connectorID
		reply.RemoteIPs = []string{}
		reply.StaticConnections = []map[string]interface{}{}
		reply.BoundRemotes = []map[string]interface{}{}

		detail := connectorDetail{}
		err := conn.ServerCall(r.Context(), "GET", "/api/v1/pfconnector/connector-detail?connector-id="+url.QueryEscape(connectorID), &detail)
		if err != nil {
			log.LoggerWContext(r.Context()).Error(fmt.Sprintf("Unable to fetch connector detail for %s: %s", connectorID, err))
			reply.Errors = append(reply.Errors, "Unable to fetch connector detail from the pfconnector server")
		} else {
			reply.connectorDetail = detail
		}

		// System stats only make sense when the tunnel is up
		if reply.Connected {
			if system, err := h.callConnectorRemoteAPI(conn, "GET", "/api/v1/system/info", nil); err != nil {
				log.LoggerWContext(r.Context()).Error(fmt.Sprintf("Unable to fetch system info for %s: %s", connectorID, err))
				reply.Errors = append(reply.Errors, "Unable to fetch system info from the connector-remote")
			} else {
				reply.System = system
			}
		}

		if central, ok := centralPFVersion(); ok {
			reply.CentralVersion = central
			if remote, ok := reply.System["version"].(string); ok {
				reply.UpgradeAvailable = versionLess(remote, central)
			}
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(reply)
	})
}

// pfReleaseFile carries the central PacketFence version ("PacketFence X.Y.Z").
const pfReleaseFile = "/usr/local/pf/conf/pf-release"

var majorMinorRe = regexp.MustCompile(`(\d+)\.(\d+)`)

// centralPFVersion extracts MAJOR.MINOR from the central pf-release file.
func centralPFVersion() (string, bool) {
	raw, err := os.ReadFile(pfReleaseFile)
	if err != nil {
		return "", false
	}
	m := majorMinorRe.FindString(string(raw))
	return m, m != ""
}

// versionLess reports whether the MAJOR.MINOR in a is lower than in b.
// Unparsable versions (e.g. a dev build's "0.0.0-src" still parses; garbage
// does not) never report an upgrade.
func versionLess(a, b string) bool {
	am := majorMinorRe.FindStringSubmatch(a)
	bm := majorMinorRe.FindStringSubmatch(b)
	if am == nil || bm == nil {
		return false
	}
	aMaj, _ := strconv.Atoi(am[1])
	aMin, _ := strconv.Atoi(am[2])
	bMaj, _ := strconv.Atoi(bm[1])
	bMin, _ := strconv.Atoi(bm[2])
	return aMaj < bMaj || (aMaj == bMaj && aMin < bMin)
}

// pfconnectorRemoteUpgrade asks the connector-remote to upgrade its package
// to the central PacketFence version: the connector's host rewrites its
// PacketFence apt repository to that version and apt-upgrades the
// packetfence-pfconnector-remote package (signature-verified against the
// PacketFence archive keyring), then its postinst restarts the connector.
func (h APIHandler) pfconnectorRemoteUpgrade() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID := chi.URLParam(r, "connectorID")
		if connectorID == "" {
			http.Error(w, "PFconnector ID is required", http.StatusBadRequest)
			return
		}

		conn := connector.NewConnectorsContainer(h.ctx).Get(h.ctx, connectorID)
		if conn == nil {
			http.Error(w, "Unknown PFconnector ID", http.StatusNotFound)
			return
		}

		central, ok := centralPFVersion()
		if !ok {
			http.Error(w, "Unable to determine the central PacketFence version", http.StatusInternalServerError)
			return
		}

		body, _ := json.Marshal(map[string]string{"version": central})
		res, err := h.callConnectorRemoteAPI(conn, "POST", "/api/v1/system/upgrade", bytes.NewReader(body))
		if err != nil {
			log.LoggerWContext(r.Context()).Error(fmt.Sprintf("Unable to trigger the upgrade of connector-remote %s: %s", connectorID, err))
			http.Error(w, "Unable to reach the connector-remote to upgrade it", http.StatusBadGateway)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(res)
	})
}

// installablePackages mirrors the allowlist of the connector-remote's
// /api/v1/system/install: the NTLM authentication services needed when an
// Active Directory domain is behind the connector.
var installablePackages = map[string]bool{
	"packetfence-ntlm-auth-api-remote":  true,
	"packetfence-ntlm-auth-join-remote": true,
}

// pfconnectorRemoteInstall asks the connector-remote's host to apt-install
// PacketFence packages from the allowlist (the host script re-checks it and
// apt verifies the signatures). The install is asynchronous: the status
// endpoint reports the host's package state and the install log.
func (h APIHandler) pfconnectorRemoteInstall() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID := chi.URLParam(r, "connectorID")
		if connectorID == "" {
			http.Error(w, "PFconnector ID is required", http.StatusBadRequest)
			return
		}
		var req struct {
			Packages []string `json:"packages"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || len(req.Packages) == 0 {
			http.Error(w, "A list of packages is required", http.StatusBadRequest)
			return
		}
		for _, p := range req.Packages {
			if !installablePackages[p] {
				http.Error(w, fmt.Sprintf("Package %q cannot be installed on a connector-remote from here", p), http.StatusBadRequest)
				return
			}
		}

		conn := connector.NewConnectorsContainer(h.ctx).Get(h.ctx, connectorID)
		if conn == nil {
			http.Error(w, "Unknown PFconnector ID", http.StatusNotFound)
			return
		}

		body, _ := json.Marshal(map[string][]string{"packages": req.Packages})
		res, err := h.callConnectorRemoteAPI(conn, "POST", "/api/v1/system/install", bytes.NewReader(body))
		if err != nil {
			log.LoggerWContext(r.Context()).Error(fmt.Sprintf("Unable to trigger the package install on connector-remote %s: %s", connectorID, err))
			http.Error(w, "Unable to reach the connector-remote to install the packages", http.StatusBadGateway)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(res)
	})
}

// pfconnectorRemoteHaSwitch asks the master of an HA group to hand the
// virtual IP over to another host of the group ({"to": "<peer address>"}),
// so host-level actions (install, terminal, logs, upgrade) then reach that
// host. The switch is a controlled failover: a few seconds of degraded mode.
func (h APIHandler) pfconnectorRemoteHaSwitch() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID := chi.URLParam(r, "connectorID")
		if connectorID == "" {
			http.Error(w, "PFconnector ID is required", http.StatusBadRequest)
			return
		}
		var req struct {
			To string `json:"to"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || net.ParseIP(req.To) == nil {
			http.Error(w, "The address of the host to make active is required", http.StatusBadRequest)
			return
		}
		conn := connector.NewConnectorsContainer(h.ctx).Get(h.ctx, connectorID)
		if conn == nil {
			http.Error(w, "Unknown PFconnector ID", http.StatusNotFound)
			return
		}
		body, _ := json.Marshal(map[string]string{"to": req.To})
		res, err := h.callConnectorRemoteAPI(conn, "POST", "/api/v1/ha/switch", bytes.NewReader(body))
		if err != nil {
			log.LoggerWContext(r.Context()).Error(fmt.Sprintf("Unable to switch the active host of connector %s to %s: %s", connectorID, req.To, err))
			http.Error(w, fmt.Sprintf("Unable to switch the active host: %s", err), http.StatusBadGateway)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(res)
	})
}

// pfconnectorForIP tells which connector serves an IP address (connectors.conf
// networks, top-down), so the domain form can point at the connector whose
// host needs the NTLM packages for a domain controller behind it.
func (h APIHandler) pfconnectorForIP() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := net.ParseIP(chi.URLParam(r, "ip"))
		if ip == nil {
			http.Error(w, "A valid IP address is required", http.StatusBadRequest)
			return
		}
		conn := connector.NewConnectorsContainer(h.ctx).ForIP(h.ctx, ip)
		w.Header().Set("Content-Type", "application/json")
		if conn == nil || conn.PfconfigHashNS == "local_connector" {
			w.WriteHeader(http.StatusNotFound)
			json.NewEncoder(w).Encode(map[string]interface{}{"message": "No connector serves this IP address", "ip": ip.String()})
			return
		}
		json.NewEncoder(w).Encode(map[string]interface{}{"connector_id": conn.PfconfigHashNS, "ip": ip.String()})
	})
}

// pfconnectorRemoteRestart asks the connector-remote to restart itself (clean
// s6 shutdown; the host systemd unit restarts the container).
func (h APIHandler) pfconnectorRemoteRestart() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID := chi.URLParam(r, "connectorID")
		if connectorID == "" {
			http.Error(w, "PFconnector ID is required", http.StatusBadRequest)
			return
		}

		conn := connector.NewConnectorsContainer(h.ctx).Get(h.ctx, connectorID)
		if conn == nil {
			http.Error(w, "Unknown PFconnector ID", http.StatusNotFound)
			return
		}

		res, err := h.callConnectorRemoteAPI(conn, "POST", "/api/v1/system/restart", nil)
		if err != nil {
			log.LoggerWContext(r.Context()).Error(fmt.Sprintf("Unable to restart connector-remote %s: %s", connectorID, err))
			http.Error(w, "Unable to reach the connector-remote to restart it", http.StatusBadGateway)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(res)
	})
}

// callConnectorRemoteAPI opens (or reuses) a dynreverse tunnel to the
// connector-remote's local API (:8081) and performs one HTTP call through it.
func (h APIHandler) callConnectorRemoteAPI(conn *connector.Connector, method, path string, body io.Reader) (map[string]interface{}, error) {
	remoteCon, err := conn.DynReverse(h.ctx, "127.0.0.1:8081")
	if err != nil {
		return nil, fmt.Errorf("dynreverse: %w", err)
	}

	client := &http.Client{Timeout: 10 * time.Second}
	req, err := http.NewRequest(method, "http://"+remoteCon.Host+":"+string(remoteCon.Port)+path, body)
	if err != nil {
		return nil, err
	}
	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code %d", res.StatusCode)
	}
	out := map[string]interface{}{}
	if err := json.NewDecoder(res.Body).Decode(&out); err != nil {
		return nil, err
	}
	return out, nil
}
