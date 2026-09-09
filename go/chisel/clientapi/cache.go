package clientapi

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
)

// The connector-remote fronts the management API of the local connector-cache
// service (packetfence-connector-cache, the offline RADIUS/credential cache
// and RADIUS rate limiter) under /api/v1/cache, so the PacketFence admin UI
// can operate it through the tunnel:
//
//	GET  /cache/stats        -> GET  /manage/stats (keys normalized to snake_case)
//	GET  /cache/config       -> GET  /manage/config
//	PUT  /cache/config       -> PUT  /manage/config (editable fields only)
//	POST /cache/optimize-db  -> POST /manage/optimize-db
//	POST /cache/clean        -> POST /manage/clean
//	POST /cache/restart      -> POST /manage/restart
//
// Every reply is JSON. connector-cache's own errors (a rejected value, an
// unknown field...) are relayed with their status code as {"message": ...};
// an unreachable service is a 502.

// connectorCacheURL is the base of the local connector-cache REST API (the
// container runs with --network=host, connector-cache listens on the host).
var connectorCacheURL = strings.TrimRight(sharedutils.EnvOrDefault("PFCONNECTOR_CONNECTOR_CACHE_URL", "http://127.0.0.1:12142/api/v1"), "/")

// connectorCacheClient bounds the management calls; VACUUM on a large cache
// database and the graceful restart are the slowest of them.
var connectorCacheClient = &http.Client{Timeout: 30 * time.Second}

// cacheConfigMaxBody caps a configuration update body.
const cacheConfigMaxBody = 64 * 1024

// cacheEditableFields are the connector-cache options the admin UI may
// change. server.port and database.path are deliberately excluded: the
// connector's own proxies (credcache, RADIUS rate limiting) and the HA
// snapshot rely on where the service listens and keeps its database.
var cacheEditableFields = map[string]bool{
	"database.cache_ram_size":      true,
	"database.startup_clean":       true,
	"app.radius_attribute_ttl":     true,
	"app.credential_ttl":           true,
	"app.radius_attribute_filters": true,
	"app.rate_limit_rate":          true,
	"app.rate_limit_reject":        true,
	"app.rate_limit_key_max_age":   true,
}

// cacheConfigField is one field/value pair of a configuration update, the
// shape connector-cache expects in {"to_update": [...]}.
type cacheConfigField struct {
	Field string      `json:"field"`
	Value interface{} `json:"value"`
}

type cacheConfigUpdate struct {
	ToUpdate []cacheConfigField `json:"to_update"`
}

// mountCacheRoutes registers the /cache routes on r (a router already
// restricted to the tunnel / localhost).
func mountCacheRoutes(r chi.Router, api *API) {
	r.Route("/cache", func(r chi.Router) {
		r.Get("/stats", cacheStats(api))
		r.Get("/config", cacheConfig(api))
		r.Put("/config", cacheConfigUpdateHandler(api))
		r.Post("/optimize-db", cacheAction(api, "optimize-db", "Expired cache entries deleted and database optimized"))
		r.Post("/clean", cacheAction(api, "clean", "RADIUS cache, credential cache and rate-limit keys wiped"))
		r.Post("/restart", cacheAction(api, "restart", "Cache service restart requested"))
	})
}

// writeJSON writes v as a JSON reply with the given status.
func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

// writeMessage writes a {"message": ...} JSON reply with the given status.
func writeMessage(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"message": message})
}

// connectorCacheCall performs one call on connector-cache's manage API and
// returns the status code and the (bounded) reply body; err is set only when
// the service could not be reached or answered garbage.
func connectorCacheCall(method, endpoint string, body io.Reader) (int, []byte, error) {
	req, err := http.NewRequest(method, connectorCacheURL+"/manage/"+endpoint, body)
	if err != nil {
		return 0, nil, err
	}
	// connector-cache only accepts application/json (chi AllowContentType).
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	res, err := connectorCacheClient.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer res.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(res.Body, 1024*1024))
	if err != nil {
		return 0, nil, err
	}
	return res.StatusCode, raw, nil
}

// relayCacheError turns a connector-cache failure into the admin-facing
// reply: 502 when the service is unreachable, otherwise its own status code
// with its (plain text) error as the message.
func relayCacheError(api *API, w http.ResponseWriter, what string, status int, raw []byte, err error) {
	if err != nil {
		log.LoggerWContext(api.ctx).Error(fmt.Sprintf("connector-cache %s: %v", what, err))
		writeMessage(w, http.StatusBadGateway, "The cache service does not answer on this connector")
		return
	}
	message := strings.TrimSpace(string(raw))
	if message == "" {
		message = fmt.Sprintf("The cache service answered %d", status)
	}
	log.LoggerWContext(api.ctx).Warn(fmt.Sprintf("connector-cache %s: %d %s", what, status, message))
	if status < 400 || status > 599 {
		status = http.StatusBadGateway
	}
	writeMessage(w, status, message)
}

// cacheStats is GET /api/v1/cache/stats.
func cacheStats(api *API) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		status, raw, err := connectorCacheCall("GET", "stats", nil)
		if err != nil || status != http.StatusOK {
			relayCacheError(api, w, "stats", status, raw, err)
			return
		}
		stats, err := decodeConnectorCacheStats(raw)
		if err != nil {
			relayCacheError(api, w, "stats", status, nil, err)
			return
		}
		writeJSON(w, http.StatusOK, stats)
	}
}

// cacheConfig is GET /api/v1/cache/config: connector-cache's configuration,
// laid out like its YAML file (database/server/app sections, snake_case).
func cacheConfig(api *API) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		status, raw, err := connectorCacheCall("GET", "config", nil)
		if err != nil || status != http.StatusOK {
			relayCacheError(api, w, "config", status, raw, err)
			return
		}
		writeCacheConfig(api, w, raw)
	}
}

// writeCacheConfig relays a configuration document after checking it is
// JSON (connector-cache converts its YAML on the fly).
func writeCacheConfig(api *API, w http.ResponseWriter, raw []byte) {
	var cfg map[string]interface{}
	if err := json.Unmarshal(raw, &cfg); err != nil {
		relayCacheError(api, w, "config", http.StatusOK, nil, fmt.Errorf("invalid configuration document: %w", err))
		return
	}
	writeJSON(w, http.StatusOK, cfg)
}

// cacheConfigUpdateHandler is PUT /api/v1/cache/config. The body is the
// connector-cache shape ({"to_update": [{"field": "app.rate_limit_rate",
// "value": 10}, ...]}); only the editable fields go through.
func cacheConfigUpdateHandler(api *API) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var update cacheConfigUpdate
		if err := json.NewDecoder(io.LimitReader(r.Body, cacheConfigMaxBody)).Decode(&update); err != nil {
			writeMessage(w, http.StatusBadRequest, "Invalid request body: "+err.Error())
			return
		}
		if len(update.ToUpdate) == 0 {
			writeMessage(w, http.StatusBadRequest, "Nothing to update")
			return
		}
		for _, f := range update.ToUpdate {
			if !cacheEditableFields[f.Field] {
				writeMessage(w, http.StatusBadRequest, fmt.Sprintf("The %q option cannot be changed from here", f.Field))
				return
			}
			if f.Value == nil {
				writeMessage(w, http.StatusBadRequest, fmt.Sprintf("The %q option needs a value", f.Field))
				return
			}
		}
		body, _ := json.Marshal(update)
		status, raw, err := connectorCacheCall("PUT", "config", bytes.NewReader(body))
		if err != nil || status != http.StatusOK {
			relayCacheError(api, w, "config update", status, raw, err)
			return
		}
		log.LoggerWContext(api.ctx).Info(fmt.Sprintf("connector-cache configuration updated: %s", body))
		writeCacheConfig(api, w, raw)
	}
}

// cacheAction is POST /api/v1/cache/{optimize-db,clean,restart}.
func cacheAction(api *API, endpoint, message string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		log.LoggerWContext(api.ctx).Info(fmt.Sprintf("connector-cache %s requested through the pfconnector-client API", endpoint))
		status, raw, err := connectorCacheCall("POST", endpoint, nil)
		if err != nil || status != http.StatusOK {
			relayCacheError(api, w, endpoint, status, raw, err)
			return
		}
		writeMessage(w, http.StatusOK, message)
	}
}

// decodeConnectorCacheStats parses connector-cache's /manage/stats reply
// (its JSON keys are Go field names) into the snake_case form the admin UI
// reads.
func decodeConnectorCacheStats(raw []byte) (*ConnectorCacheStats, error) {
	var in struct {
		MemAlloc        int64
		MemSys          int64
		DBSize          int64
		DevicesInDB     int
		CredentialInDB  int
		KeysInRatelimit int
	}
	if err := json.Unmarshal(raw, &in); err != nil {
		return nil, err
	}
	return &ConnectorCacheStats{
		MemAlloc:        in.MemAlloc,
		MemSys:          in.MemSys,
		DBSize:          in.DBSize,
		DevicesInDB:     in.DevicesInDB,
		CredentialInDB:  in.CredentialInDB,
		KeysInRatelimit: in.KeysInRatelimit,
	}, nil
}
