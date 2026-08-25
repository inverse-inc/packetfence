package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/redis/go-redis/v9"
)

// proxyTerminal reverse proxies /api/v1/terminal/{connectorID}/* to the
// connector-remote's local API (:8081) through an on-demand dynreverse
// tunnel, which in turn proxies to the remote's gotty terminal.
func (h APIHandler) proxyTerminal() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID := chi.URLParam(r, "connectorID")
		if connectorID == "" {
			http.Error(w, "PFconnector ID is required", http.StatusBadRequest)
			return
		}

		r.URL.Path = strings.TrimPrefix(r.URL.Path, "/api/v1/terminal/"+connectorID)
		r.Host = "127.0.0.1:8081"
		r.URL.Path = "api/v1/terminal" + r.URL.Path
		r.Header.Set("X-Forwarded-For", "127.0.0.1")

		conn := connector.NewConnectorsContainer(h.ctx)
		remoteCon, err := conn.Get(h.ctx, connectorID).DynReverse(h.ctx, fmt.Sprintf("%s:%s", "127.0.0.1", "8081"))
		if err != nil {
			http.Error(w, "Failed to connect to PFconnector", http.StatusInternalServerError)
			return
		}

		terminalURL, err := url.Parse("http://" + remoteCon.Host + ":" + string(remoteCon.Port))
		if err != nil {
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}
		w.Header().Del("Content-Type")
		proxy := httputil.NewSingleHostReverseProxy(terminalURL)
		proxy.ServeHTTP(w, r)
	})
}

// proxyTerminalAuthorize activates a terminal session on the
// connector-remote through a dynreverse tunnel, so the admin's browser never
// needs direct network access to the remote.
func (h APIHandler) proxyTerminalAuthorize() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID := chi.URLParam(r, "connectorID")
		sessionUUID := chi.URLParam(r, "uuid")
		if connectorID == "" || sessionUUID == "" {
			http.Error(w, "PFconnector ID and session uuid are required", http.StatusBadRequest)
			return
		}

		conn := connector.NewConnectorsContainer(h.ctx).Get(h.ctx, connectorID)
		if conn == nil {
			http.Error(w, "Unknown PFconnector ID", http.StatusNotFound)
			return
		}
		remoteCon, err := conn.DynReverse(h.ctx, "127.0.0.1:8081")
		if err != nil {
			http.Error(w, "Failed to connect to PFconnector", http.StatusInternalServerError)
			return
		}

		authorizeURL := "http://" + remoteCon.Host + ":" + string(remoteCon.Port) + "/api/v1/authorize/" + sessionUUID
		// Relay the TOTP code; it is validated by the connector-remote
		// against the seed stored on its own filesystem.
		if code := r.URL.Query().Get("code"); code != "" {
			authorizeURL += "?code=" + url.QueryEscape(code)
		}
		res, err := http.Get(authorizeURL)
		if err != nil {
			http.Error(w, "Failed to activate terminal on the connector-remote", http.StatusBadGateway)
			return
		}
		defer res.Body.Close()
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(res.StatusCode)
		io.Copy(w, res.Body)
	})
}

// pfconnectorTerminalGet creates a one-time terminal session for a
// connector: it stores terminal:<uuid> -> connector id in the pfconnector
// Redis (validated by the chisel server's remote-terminal endpoint) and
// returns the URL, on the remote's own IP, that activates the session.
func (h APIHandler) pfconnectorTerminalGet() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		type request struct {
			PFconnectorID string `json:"pfconnector_id"`
		}
		type reply struct {
			UUID        string `json:"uuid"`
			RedirectURL string `json:"redirect_url"`
		}

		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Failed to read request body", http.StatusBadRequest)
			return
		}
		var req request
		json.Unmarshal(body, &req)
		if len(req.PFconnectorID) == 0 {
			http.Error(w, "PFconnector ID is required", http.StatusBadRequest)
			return
		}

		pfconnectorConfiguration := pfconfigdriver.GetType[pfconfigdriver.PfConfPfconnector](r.Context())
		network := "tcp"
		if strings.HasPrefix(pfconnectorConfiguration.RedisServer, "/") {
			network = "unix"
		}

		redisClient := redis.NewClient(&redis.Options{
			Addr:    pfconnectorConfiguration.RedisServer,
			Network: network,
		})
		defer redisClient.Close()

		if err := redisClient.Ping(r.Context()).Err(); err != nil {
			http.Error(w, "Redis server is not reachable", http.StatusInternalServerError)
			return
		}

		newUUID := uuid.New()
		if err := redisClient.Set(r.Context(), "terminal:"+newUUID.String(), req.PFconnectorID, 0).Err(); err != nil {
			http.Error(w, "Failed to store PFconnector ID", http.StatusInternalServerError)
			return
		}

		redirect := reply{UUID: newUUID.String()}
		// Legacy direct-activation URL, usable when the admin's browser can
		// reach the remote's IP. The proxied activation
		// (/api/v1/terminal/{connectorID}/authorize/{uuid}) works everywhere.
		ips := redisClient.Get(r.Context(), "ips:"+req.PFconnectorID).Val()
		ipList := strings.Split(ips, ",")
		if len(ipList) > 0 && ipList[0] != "" {
			redirect.RedirectURL = "http://" + ipList[0] + ":8081/api/v1/authorize/" + newUUID.String()
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		if err := json.NewEncoder(w).Encode(redirect); err != nil {
			http.Error(w, "Failed to encode response", http.StatusInternalServerError)
			return
		}
	})
}
