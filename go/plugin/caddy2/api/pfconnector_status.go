package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
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
