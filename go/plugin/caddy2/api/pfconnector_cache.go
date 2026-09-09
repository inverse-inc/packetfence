package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/connector"
)

// Management of the connector-cache service running on a connector-remote
// (the offline RADIUS/credential cache and RADIUS rate limiter), relayed to
// the remote's /api/v1/cache routes over a dynreverse tunnel:
//
//	GET  /pfconnector-remotes/{id}/cache/stats
//	GET  /pfconnector-remotes/{id}/cache/config
//	PUT  /pfconnector-remotes/{id}/cache/config   {"to_update": [{"field": "app.rate_limit_rate", "value": 10}, ...]}
//	POST /pfconnector-remotes/{id}/cache/optimize-db
//	POST /pfconnector-remotes/{id}/cache/clean
//	POST /pfconnector-remotes/{id}/cache/restart
//
// Under /pfconnector-remotes the routes inherit the CONNECTORS admin role
// (GET: _READ, PUT: _UPDATE, POST: _CREATE, see aaa/authorization.go). The
// remote validates the update (editable fields only) and connector-cache
// type-checks and range-validates every value; their JSON {"message": ...}
// errors are relayed with their status code so the admin sees why a change
// was refused.

// cacheConfigUpdateMaxBody caps a configuration update body.
const cacheConfigUpdateMaxBody = 64 * 1024

// mountPfconnectorCacheRoutes registers the cache management routes under
// /pfconnector-remotes/{connectorID}/cache.
func (h APIHandler) mountPfconnectorCacheRoutes(r chi.Router) {
	r.Route("/{connectorID}/cache", func(r chi.Router) {
		r.Get("/stats", h.pfconnectorRemoteCacheRelay("GET", "stats"))
		r.Get("/config", h.pfconnectorRemoteCacheRelay("GET", "config"))
		r.Put("/config", h.pfconnectorRemoteCacheRelay("PUT", "config"))
		r.Post("/optimize-db", h.pfconnectorRemoteCacheRelay("POST", "optimize-db"))
		r.Post("/clean", h.pfconnectorRemoteCacheRelay("POST", "clean"))
		r.Post("/restart", h.pfconnectorRemoteCacheRelay("POST", "restart"))
	})
}

// pfconnectorRemoteCacheRelay forwards one cache management call to the
// connector-remote (method and /api/v1/cache/{endpoint}), body included for
// PUT, and relays its JSON reply and status code.
func (h APIHandler) pfconnectorRemoteCacheRelay(method, endpoint string) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID := chi.URLParam(r, "connectorID")
		if connectorID == "" {
			writeJSONMessage(w, http.StatusBadRequest, "PFconnector ID is required")
			return
		}
		conn := connector.NewConnectorsContainer(h.ctx).Get(h.ctx, connectorID)
		if conn == nil {
			writeJSONMessage(w, http.StatusNotFound, "Unknown PFconnector ID")
			return
		}

		var body io.Reader
		if method == "PUT" {
			raw, err := io.ReadAll(io.LimitReader(r.Body, cacheConfigUpdateMaxBody+1))
			if err != nil || len(raw) > cacheConfigUpdateMaxBody {
				writeJSONMessage(w, http.StatusBadRequest, "Invalid or oversized request body")
				return
			}
			var update struct {
				ToUpdate []json.RawMessage `json:"to_update"`
			}
			if err := json.Unmarshal(raw, &update); err != nil || len(update.ToUpdate) == 0 {
				writeJSONMessage(w, http.StatusBadRequest, "A non-empty to_update list is required")
				return
			}
			body = bytes.NewReader(raw)
			log.LoggerWContext(r.Context()).Info(fmt.Sprintf("Updating the connector-cache configuration of %s: %s", connectorID, raw))
		} else if method == "POST" {
			log.LoggerWContext(r.Context()).Info(fmt.Sprintf("connector-cache %s requested on %s", endpoint, connectorID))
		}

		status, reply, err := h.callConnectorRemoteAPIRaw(conn, method, "/api/v1/cache/"+endpoint, body, 40*time.Second)
		if err != nil {
			log.LoggerWContext(r.Context()).Error(fmt.Sprintf("Unable to reach the cache API of connector-remote %s (%s %s): %s", connectorID, method, endpoint, err))
			writeJSONMessage(w, http.StatusBadGateway, "Unable to reach the connector-remote")
			return
		}
		if status == http.StatusNotFound {
			// A connector-remote predating the cache management routes
			// answers chi's plain 404.
			writeJSONMessage(w, http.StatusNotFound, "This connector-remote does not expose the cache management API: upgrade it first")
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(status)
		if json.Valid(reply) {
			w.Write(reply)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"message": string(reply)})
	})
}

// writeJSONMessage writes a {"message": ...} JSON reply with the given status.
func writeJSONMessage(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"message": message})
}

// callConnectorRemoteAPIRaw opens (or reuses) a dynreverse tunnel to the
// connector-remote's local API (:8081), performs one HTTP call through it
// and returns the status code and the (bounded) reply body, whatever the
// status: the caller decides how to relay it. Unlike callConnectorRemoteAPI
// it does not require a 200 nor a JSON object.
func (h APIHandler) callConnectorRemoteAPIRaw(conn *connector.Connector, method, path string, body io.Reader, timeout time.Duration) (int, []byte, error) {
	remoteCon, err := conn.DynReverse(h.ctx, "127.0.0.1:8081")
	if err != nil {
		return 0, nil, fmt.Errorf("dynreverse: %w", err)
	}
	client := &http.Client{Timeout: timeout}
	req, err := http.NewRequest(method, "http://"+remoteCon.Host+":"+string(remoteCon.Port)+path, body)
	if err != nil {
		return 0, nil, err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	res, err := client.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer res.Body.Close()
	reply, err := io.ReadAll(io.LimitReader(res.Body, 1024*1024))
	if err != nil {
		return 0, nil, err
	}
	return res.StatusCode, reply, nil
}
