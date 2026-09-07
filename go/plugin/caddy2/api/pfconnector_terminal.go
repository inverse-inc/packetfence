package api

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/redis/go-redis/v9"
)

// stripAdminCredentials removes the admin's API credentials from a request
// that is reverse-proxied to a connector-remote: the remote host is only
// semi-trusted (a customer site) and must never see a live admin token, be
// it the Authorization header or the token cookie the aaa layer accepts.
func stripAdminCredentials(req *http.Request) {
	req.Header.Del("Authorization")
	req.Header.Del("Cookie")
	req.Header.Del("X-PacketFence-Username")
	req.Header.Del("X-PacketFence-Admin-Roles")
}

// terminalPageCSP isolates the terminal page. gotty's HTML and JavaScript are
// authored by the connector-remote but served from the admin origin (this
// proxy path); a sandbox without allow-same-origin gives that document an
// opaque origin, so it cannot read the admin's local storage, cookies or
// opener while still running its scripts and opening its websocket.
const terminalPageCSP = "sandbox allow-scripts allow-forms"

// proxyTerminal reverse proxies /api/v1/terminal/{connectorID}/* to the
// connector-remote's local API (:8081) through an on-demand dynreverse
// tunnel, which in turn proxies to the remote's gotty terminal.
func (h APIHandler) proxyTerminal() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID, _ := url.PathUnescape(chi.URLParam(r, "connectorID"))
		if connectorID == "" {
			http.Error(w, "PFconnector ID is required", http.StatusBadRequest)
			return
		}
		conn := connector.NewConnectorsContainer(h.ctx).Get(h.ctx, connectorID)
		if conn == nil {
			http.Error(w, "Unknown PFconnector ID", http.StatusNotFound)
			return
		}
		// The rest of the path after the connector id, as routed by chi
		// (empty for /terminal/{connectorID}/).
		rest := chi.URLParam(r, "*")
		r.URL.Path = "/api/v1/terminal/" + rest
		r.URL.RawPath = ""
		r.Host = "127.0.0.1:8081"
		r.Header.Set("X-Forwarded-For", "127.0.0.1")
		remoteCon, err := conn.DynReverse(h.ctx, "127.0.0.1:8081")
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
		director := proxy.Director
		proxy.Director = func(req *http.Request) {
			director(req)
			stripAdminCredentials(req)
		}
		proxy.ModifyResponse = func(res *http.Response) error {
			if strings.HasPrefix(res.Header.Get("Content-Type"), "text/html") {
				res.Header.Set("Content-Security-Policy", terminalPageCSP)
				res.Header.Set("X-Frame-Options", "DENY")
			}
			return nil
		}
		proxy.ServeHTTP(w, r)
	})
}

// terminalAuthorizeClient bounds the activation call through the tunnel.
var terminalAuthorizeClient = &http.Client{Timeout: 15 * time.Second}

// TOTPCodeHeader carries the admin's TOTP code to the connector-remote. A
// header rather than a query parameter: query strings end up in the access
// logs of every hop.
const TOTPCodeHeader = "X-PF-TOTP-Code"

// proxyTerminalAuthorize activates a terminal session on the
// connector-remote through a dynreverse tunnel, so the admin's browser never
// needs direct network access to the remote.
func (h APIHandler) proxyTerminalAuthorize() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID, _ := url.PathUnescape(chi.URLParam(r, "connectorID"))
		sessionUUID, _ := url.PathUnescape(chi.URLParam(r, "uuid"))
		if connectorID == "" || sessionUUID == "" {
			http.Error(w, "PFconnector ID and session uuid are required", http.StatusBadRequest)
			return
		}
		if _, err := uuid.Parse(sessionUUID); err != nil {
			http.Error(w, "Invalid session uuid", http.StatusBadRequest)
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
		authorizeURL := "http://" + remoteCon.Host + ":" + string(remoteCon.Port) + "/api/v1/authorize/" + url.PathEscape(sessionUUID)
		req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, authorizeURL, nil)
		if err != nil {
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}
		// Relay the TOTP code; it is validated by the connector-remote
		// against the seed stored on its own filesystem. Accepted from the
		// header, or from the query for older admin UIs.
		code := r.Header.Get(TOTPCodeHeader)
		if code == "" {
			code = r.URL.Query().Get("code")
		}
		if code != "" {
			req.Header.Set(TOTPCodeHeader, code)
		}
		res, err := terminalAuthorizeClient.Do(req)
		if err != nil {
			http.Error(w, "Failed to activate terminal on the connector-remote", http.StatusBadGateway)
			return
		}
		defer res.Body.Close()
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(res.StatusCode)
		io.Copy(w, io.LimitReader(res.Body, 64<<10))
	})
}

// terminalSessionTTL is how long a terminal activation uuid stays valid.
const terminalSessionTTL = 5 * time.Minute

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
		// Short-lived: an activation token the admin never used must not
		// stay valid forever (it is in the browser history and the logs).
		if err := redisClient.Set(r.Context(), "terminal:"+newUUID.String(), req.PFconnectorID, terminalSessionTTL).Err(); err != nil {
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
