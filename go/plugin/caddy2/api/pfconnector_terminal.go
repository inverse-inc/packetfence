package api

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"io/fs"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	texttemplate "text/template"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/redis/go-redis/v9"
	"github.com/sorenisanerd/gotty/bindata"
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

// terminalSecretKey holds the secret the connector-remote generated when the
// current terminal session was authorized. The remote only accepts the
// terminal websocket with it, so the session is enforced on the remote too,
// not only by this API. It never leaves the server side.
func terminalSecretKey(connectorID string) string {
	return "terminal-secret:" + connectorID
}

// terminalSecretHeader carries the session secret to the connector-remote.
const terminalSecretHeader = "X-PacketFence-Terminal-Secret"

// terminalTitle is the title of the terminal page.
const terminalTitle = "pfconnector-remote"

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
	redisClient.Expire(r.Context(), terminalSecretKey(connectorID), terminalAccessTTL)
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

// gottyAssets are the static files of the gotty web terminal, embedded in this
// binary: the terminal page is served by this API, never by the remote.
var gottyAssets = func() fs.FS {
	assets, err := fs.Sub(bindata.Fs, "static")
	if err != nil {
		panic(err)
	}
	return assets
}()

var gottyIndexTemplate = template.Must(template.ParseFS(bindata.Fs, "static/index.html"))
var gottyManifestTemplate = texttemplate.Must(texttemplate.ParseFS(bindata.Fs, "static/manifest.json"))

// terminalPageHeaders are the headers of the terminal page and its assets:
// scripts, styles and the websocket of this origin only.
func terminalPageHeaders(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Content-Security-Policy", "default-src 'none'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; manifest-src 'self'; connect-src 'self' wss://"+r.Host+"; base-uri 'none'; form-action 'none'; frame-ancestors 'none'")
	w.Header().Set("Cache-Control", "no-store")
}

// proxyTerminal serves the terminal of a connector-remote under
// /api/v1/terminal/{connectorID}/. The page, its scripts and styles are the
// gotty assets embedded in this binary, so nothing the remote answers is
// rendered in the admin origin. Only the websocket (.../ws) goes to the
// remote: through an on-demand dynreverse tunnel to its local API (:8081),
// without the admin's credentials, and with the secret of the terminal
// session that the remote checks before reaching its gotty server.
func (h APIHandler) proxyTerminal() http.HandlerFunc {
	staticFiles := http.FileServer(http.FS(gottyAssets))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// chi routes on the escaped path: unescape the id, and take the rest
		// of the path from the route's wildcard rather than r.URL.Path.
		connectorID, _ := url.PathUnescape(chi.URLParam(r, "connectorID"))
		if connectorID == "" {
			http.Error(w, "PFconnector ID is required", http.StatusBadRequest)
			return
		}

		// Only the browser that authorized the session (PF-TERMINAL cookie)
		if !validTerminalAccess(r, connectorID) {
			http.Error(w, "No authorized terminal session for this PFconnector", http.StatusForbidden)
			return
		}

		// The plugin's default JSON content type doesn't apply here
		w.Header().Del("Content-Type")
		path := "/" + chi.URLParam(r, "*")
		switch {
		case path == "/ws":
			h.proxyTerminalWebsocket(w, r, connectorID)
		case path == "/":
			terminalPageHeaders(w, r)
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			gottyIndexTemplate.Execute(w, map[string]interface{}{"title": terminalTitle})
		case path == "/manifest.json":
			terminalPageHeaders(w, r)
			w.Header().Set("Content-Type", "application/manifest+json")
			gottyManifestTemplate.Execute(w, map[string]interface{}{"title": terminalTitle})
		case path == "/auth_token.js":
			// The session is enforced by the access cookie here and by the
			// session secret on the remote: gotty's own token is not used.
			terminalPageHeaders(w, r)
			w.Header().Set("Content-Type", "application/javascript")
			w.Write([]byte("var gotty_auth_token = '';"))
		case path == "/config.js":
			terminalPageHeaders(w, r)
			w.Header().Set("Content-Type", "application/javascript")
			w.Write([]byte("var gotty_term = 'xterm';"))
		case strings.HasPrefix(path, "/js/") || strings.HasPrefix(path, "/css/") ||
			path == "/favicon.ico" || path == "/icon.svg" || path == "/icon_192.png":
			terminalPageHeaders(w, r)
			r2 := r.Clone(r.Context())
			r2.URL.Path = path
			r2.URL.RawPath = ""
			staticFiles.ServeHTTP(w, r2)
		default:
			http.NotFound(w, r)
		}
	})
}

// proxyTerminalWebsocket proxies the terminal websocket to the
// connector-remote with the secret of the current session.
func (h APIHandler) proxyTerminalWebsocket(w http.ResponseWriter, r *http.Request, connectorID string) {
	if !isWebsocketUpgrade(r) {
		http.Error(w, "Only websocket requests are accepted", http.StatusBadRequest)
		return
	}
	if !sameOriginWebsocket(r) {
		http.Error(w, "Cross-origin request refused", http.StatusForbidden)
		return
	}
	secret, err := pfconnectorRedis(r.Context()).Get(r.Context(), terminalSecretKey(connectorID)).Result()
	if err != nil || secret == "" {
		http.Error(w, "No authorized terminal session for this PFconnector", http.StatusForbidden)
		return
	}

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
	newRemoteWebsocketProxy(terminalURL, "/api/v1/terminal/ws", http.Header{terminalSecretHeader: {secret}}).ServeHTTP(w, r)
}

// terminalAuthorizeClient calls the authorize endpoint of the remotes. The
// remote validates the session with the pfconnector server first, hence a
// longer timeout than the other calls.
var terminalAuthorizeClient = &http.Client{Timeout: 30 * time.Second}

// TOTPCodeHeader carries the admin's TOTP code to the connector-remote. A
// header rather than a query parameter: query strings end up in the access
// logs of every hop.
const TOTPCodeHeader = "X-PF-TOTP-Code"

// redirectTerminal sends /api/v1/terminal/{connectorID} to the terminal page,
// whose relative asset URLs need the trailing slash.
func (h APIHandler) redirectTerminal() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID, _ := url.PathUnescape(chi.URLParam(r, "connectorID"))
		http.Redirect(w, r, terminalPath(connectorID), http.StatusMovedPermanently)
	})
}

// proxyTerminalAuthorize activates a terminal session on the
// connector-remote through a dynreverse tunnel, so the admin's browser never
// needs direct network access to the remote. The remote answers with the
// secret of the session, kept server side next to the access token.
func (h APIHandler) proxyTerminalAuthorize() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		connectorID, _ := url.PathUnescape(chi.URLParam(r, "connectorID"))
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
		req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, authorizeURL, nil)
		if err != nil {
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}
		// Relay the TOTP code; it is validated by the connector-remote
		// against the seed stored on its own filesystem. Accepted from the
		// header, or from the query for older admin UIs; sent in a header
		// (query strings end up in the access logs of every hop).
		code := r.Header.Get(TOTPCodeHeader)
		if code == "" {
			code = r.URL.Query().Get("code")
		}
		if code != "" {
			req.Header.Set(TOTPCodeHeader, code)
		}
		// Who is opening the shell, for the session's recordings (the aaa
		// layer sets the username from the validated token).
		if admin := r.Header.Get("X-PacketFence-Username"); admin != "" {
			req.Header.Set(AdminUserHeader, admin)
		}
		res, err := terminalAuthorizeClient.Do(req)
		if err != nil {
			http.Error(w, "Failed to activate terminal on the connector-remote", http.StatusBadGateway)
			return
		}
		defer res.Body.Close()
		body, _ := io.ReadAll(io.LimitReader(res.Body, 4096))

		if res.StatusCode != http.StatusOK {
			// The reason given by the remote (wrong code, locked, ...), as
			// plain text only
			msg := strings.TrimSpace(string(body))
			if len(msg) > 512 {
				msg = msg[:512]
			}
			w.Header().Set("Content-Type", "text/plain; charset=utf-8")
			w.Header().Set("X-Content-Type-Options", "nosniff")
			w.WriteHeader(res.StatusCode)
			w.Write([]byte(msg))
			return
		}

		var activation struct {
			Secret string `json:"secret"`
		}
		if err := json.Unmarshal(body, &activation); err != nil || len(activation.Secret) < 32 {
			http.Error(w, "The connector-remote didn't return a terminal session secret, upgrade it", http.StatusBadGateway)
			return
		}
		if err := pfconnectorRedis(r.Context()).Set(r.Context(), terminalSecretKey(connectorID), activation.Secret, terminalAccessTTL).Err(); err != nil {
			http.Error(w, "Failed to store the terminal session", http.StatusInternalServerError)
			return
		}
		if err := grantTerminalAccess(w, r, connectorID); err != nil {
			http.Error(w, "Failed to grant access to the terminal", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"message":"Terminal is enabled"}`))
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
