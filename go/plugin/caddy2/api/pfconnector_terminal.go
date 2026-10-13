package api

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/redis/go-redis/v9"
)

// terminalSessionTTL bounds how long a terminal session uuid created by
// pfconnectorTerminalGet can wait for its authorize call.
const terminalSessionTTL = 2 * time.Minute

// terminalAccessTTL is how long a terminal access token stays valid without
// any request through proxyTerminal; each proxied request renews it.
const terminalAccessTTL = time.Hour

// terminalAccessCookie holds the access token issued once a terminal session
// is authorized. It is scoped to the path of that connector's terminal.
const terminalAccessCookie = "PF-TERMINAL"

func terminalAccessKey(connectorID string) string {
	return "terminal-access:" + connectorID
}

func terminalPath(connectorID string) string {
	return "/api/v1/terminal/" + url.PathEscape(connectorID) + "/"
}

// sharedConnectors is the connectors container shared by the requests of
// the API. It is created on first use and refreshed on each use, which only
// re-instantiates the connectors when their configuration changed, instead of
// building every connector again on each request.
type sharedConnectors struct {
	once      sync.Once
	container *connector.ConnectorsContainer
}

// pfconnectors returns the shared connectors container, refreshed.
func (h APIHandler) pfconnectors(ctx context.Context) *connector.ConnectorsContainer {
	h.connectors.once.Do(func() {
		h.connectors.container = connector.NewConnectorsContainer(h.ctx)
	})
	h.connectors.container.Refresh(ctx)
	return h.connectors.container
}

// pfconnector returns the connector id, or nil if it does not exist.
func (h APIHandler) pfconnector(ctx context.Context, id string) *connector.Connector {
	return h.pfconnectors(ctx).Get(ctx, id)
}

// pfconnectorForIP returns the connector that holds the static tunnel
// towards ip, or nil.
func (h APIHandler) pfconnectorForIP(ctx context.Context, ip net.IP) *connector.Connector {
	return h.pfconnectors(ctx).ForIP(ctx, ip)
}

var pfconnectorRedisClient struct {
	sync.Mutex
	addr   string
	client *redis.Client
}

// pfconnectorRedis returns the client of the pfconnector Redis, the one the
// chisel server uses to validate terminal sessions. The client, and its
// connection pool, is shared by all the requests; it is only replaced when
// the configured Redis server changes. Callers must not close it.
func pfconnectorRedis(ctx context.Context) *redis.Client {
	pfconnectorConfiguration := pfconfigdriver.GetType[pfconfigdriver.PfConfPfconnector](ctx)
	addr := pfconnectorConfiguration.RedisServer

	pfconnectorRedisClient.Lock()
	defer pfconnectorRedisClient.Unlock()
	if pfconnectorRedisClient.client != nil && pfconnectorRedisClient.addr == addr {
		return pfconnectorRedisClient.client
	}
	if pfconnectorRedisClient.client != nil {
		pfconnectorRedisClient.client.Close()
	}
	network := "tcp"
	if strings.HasPrefix(addr, "/") {
		network = "unix"
	}
	pfconnectorRedisClient.addr = addr
	pfconnectorRedisClient.client = redis.NewClient(&redis.Options{
		Addr:    addr,
		Network: network,
	})
	return pfconnectorRedisClient.client
}

// validTerminalAccess checks that the request carries the access token issued
// to the browser that authorized the current terminal session of the
// connector, and renews its TTL.
func validTerminalAccess(r *http.Request, connectorID string) bool {
	cookie, err := r.Cookie(terminalAccessCookie)
	if err != nil || cookie.Value == "" {
		return false
	}
	redisClient := pfconnectorRedis(r.Context())
	token, err := redisClient.Get(r.Context(), terminalAccessKey(connectorID)).Result()
	if err != nil || subtle.ConstantTimeCompare([]byte(token), []byte(cookie.Value)) != 1 {
		return false
	}
	redisClient.Expire(r.Context(), terminalAccessKey(connectorID), terminalAccessTTL)
	return true
}

// grantTerminalAccess issues a new access token for the connector's terminal,
// replacing the previous one, and sets it as a cookie scoped to the terminal
// path. Only the browser that passed the authorize step (session uuid and
// TOTP code) can then reach the terminal through proxyTerminal.
func grantTerminalAccess(w http.ResponseWriter, r *http.Request, connectorID string) error {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return err
	}
	token := hex.EncodeToString(b)
	redisClient := pfconnectorRedis(r.Context())
	if err := redisClient.Set(r.Context(), terminalAccessKey(connectorID), token, terminalAccessTTL).Err(); err != nil {
		return err
	}
	http.SetCookie(w, &http.Cookie{
		Name:     terminalAccessCookie,
		Value:    token,
		Path:     terminalPath(connectorID),
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteStrictMode,
	})
	return nil
}

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

		// gotty has no authentication of its own: without this check, any
		// request reaching this route would attach to a terminal opened by
		// someone else.
		if !validTerminalAccess(r, connectorID) {
			http.Error(w, "No authorized terminal session for this PFconnector", http.StatusForbidden)
			return
		}

		r.URL.Path = strings.TrimPrefix(r.URL.Path, "/api/v1/terminal/"+connectorID)
		r.Host = "127.0.0.1:8081"
		r.URL.Path = "/api/v1/terminal" + r.URL.Path
		r.Header.Set("X-Forwarded-For", "127.0.0.1")
		// Never forward the admin's credentials (API token cookie or header,
		// terminal access token) to the connector-remote: gotty needs none
		// of them.
		r.Header.Del("Cookie")
		r.Header.Del("Authorization")

		conn := h.pfconnector(h.ctx, connectorID)
		if conn == nil {
			http.Error(w, "Unknown PFconnector ID", http.StatusNotFound)
			return
		}
		remoteCon, err := conn.DynReverse(h.ctx, fmt.Sprintf("%s:%s", "127.0.0.1", "8081"))
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

		conn := h.pfconnector(h.ctx, connectorID)
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
		if res.StatusCode == http.StatusOK {
			if err := grantTerminalAccess(w, r, connectorID); err != nil {
				http.Error(w, "Failed to grant access to the terminal", http.StatusInternalServerError)
				return
			}
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(res.StatusCode)
		io.Copy(w, res.Body)
	})
}

// pfconnectorTerminalGet creates a one-time terminal session for a
// connector: it stores terminal:<uuid> -> connector id in the pfconnector
// Redis, valid for terminalSessionTTL, which the chisel server's
// remote-terminal endpoint validates and consumes when the session is
// authorized through proxyTerminalAuthorize.
func (h APIHandler) pfconnectorTerminalGet() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		type request struct {
			PFconnectorID string `json:"pfconnector_id"`
		}
		type reply struct {
			UUID string `json:"uuid"`
		}

		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Failed to read request body", http.StatusBadRequest)
			return
		}
		var req request
		if err := json.Unmarshal(body, &req); err != nil {
			http.Error(w, "Invalid request body", http.StatusBadRequest)
			return
		}
		if len(req.PFconnectorID) == 0 {
			http.Error(w, "PFconnector ID is required", http.StatusBadRequest)
			return
		}

		redisClient := pfconnectorRedis(r.Context())

		if err := redisClient.Ping(r.Context()).Err(); err != nil {
			http.Error(w, "Redis server is not reachable", http.StatusInternalServerError)
			return
		}

		newUUID := uuid.New()
		if err := redisClient.Set(r.Context(), "terminal:"+newUUID.String(), req.PFconnectorID, terminalSessionTTL).Err(); err != nil {
			http.Error(w, "Failed to store PFconnector ID", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		if err := json.NewEncoder(w).Encode(reply{UUID: newUUID.String()}); err != nil {
			http.Error(w, "Failed to encode response", http.StatusInternalServerError)
			return
		}
	})
}
