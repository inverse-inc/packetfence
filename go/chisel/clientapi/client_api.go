package clientapi

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/chisel/share/connauth"
	"github.com/inverse-inc/packetfence/go/chisel/share/tunnel"
)

const credcacheRoutePrefix = "/api/v1/credcache"
const defaultCredcacheTarget = "http://127.0.0.1:12142/api/v1/credcache/"

// Handler struct
type API struct {
	Router          *chi.Mux
	ConnectorId     string
	TerminalEnabled bool
	// LogsEnabled mirrors PFCONNECTOR_LOGS (default true): whether the
	// live log streaming endpoint is available.
	LogsEnabled bool
	ctx         context.Context
	cancel      context.CancelFunc
	// tunnel is the chisel tunnel of the running client; nil while there is
	// none. Guarded by tunnelMu because HA mode swaps it whenever the VIP
	// moves (SetTunnel). Pointer to the mutex so it survives API being
	// copied by value.
	tunnel        *tunnel.Tunnel
	tunnelMu      *sync.RWMutex
	mdCache       *multiDomainCache
	statusCache   *connectorStatusCache
	commandChan   chan Message
	serverRunning int32
	// cacheHistory is the sampled connector-cache statistics (cache_history.go).
	cacheHistory *cacheHistory
	// terminalActivity is the unix-nano timestamp of the last terminal
	// activity (user input to the pty). Pointer so it survives API being copied.
	terminalActivity *atomic.Int64
	// terminalIdleTimeout is the idle timeout (nanoseconds) of the current
	// activation, read by the idle watcher of the running terminal.
	terminalIdleTimeout atomic.Int64
	// terminalTOTPRequired mirrors PFCONNECTOR_TERMINAL_TOTP (default true):
	// whether activating the terminal requires the TOTP second factor.
	terminalTOTPRequired bool
	// terminalTOTP is the connector-local second factor required to activate
	// the terminal. nil while terminalTOTPRequired means activation is
	// refused (fail closed). Guarded by terminalTOTPMu: a standby host of an
	// HA group replaces it when it adopts the active host's seed (hatotp.go).
	terminalTOTP   *terminalTOTP
	terminalTOTPMu sync.RWMutex
	// terminalRecording is the session recording policy (environment),
	// shared by the gotty slave factory and the recordings routes.
	terminalRecording terminalRecordingConfig
	// terminalSecret is the secret of the current terminal session. Pointer
	// so it survives API being copied.
	terminalSecret *terminalSessionSecret
}

// terminalRunning reports whether a terminal session is currently active.
func (api *API) terminalRunning() bool {
	return atomic.LoadInt32(&api.serverRunning) == 1
}

// terminalSessionSecret is the secret generated when a terminal session is
// authorized and handed to the pfconnector server's API, which sends it with
// the terminal websocket. The terminal is only reachable with it: being able
// to reach this API (the tunnel bind on the server) is not enough.
type terminalSessionSecret struct {
	mu     sync.Mutex
	secret string
}

// renew replaces the secret of the session and returns the new one.
func (t *terminalSessionSecret) renew() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	t.secret = hex.EncodeToString(b)
	return t.secret, nil
}

// clear ends the session: no secret matches anymore.
func (t *terminalSessionSecret) clear() {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.secret = ""
}

// valid reports whether secret is the one of the current session.
func (t *terminalSessionSecret) valid(secret string) bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.secret != "" && subtle.ConstantTimeCompare([]byte(t.secret), []byte(secret)) == 1
}

// terminalSecretHeader carries the session secret, set by the pfconnector
// server's API.
const terminalSecretHeader = "X-PacketFence-Terminal-Secret"

// MessageType is a command for the gotty terminal lifecycle goroutine.
type MessageType int

const (
	StartProcessing MessageType = iota
	StopProcessing
)

// Message carries a command for the terminal lifecycle goroutine.
type Message struct {
	Type MessageType
	// Session is the activation uuid (StartProcessing only); it names the
	// session's recordings. AdminUser is the PacketFence admin who
	// activated it (may be empty), stored in the recordings' header.
	Session   string
	AdminUser string
	// IdleTimeout (StartProcessing only) stops the terminal once it has seen
	// no activity for that long; it re-arms the watcher of a running one.
	IdleTimeout time.Duration
}

type Service struct {
	Name string `json:"service"`
}

// NewApi returns a pointer: the route closures, the cache refreshers and the
// callers (SetTunnel from the HA loop) must all see the same instance.
func NewApi(ctx context.Context, ConnectorID string, tun *tunnel.Tunnel) *API {
	Api := API{}
	Api.Router = chi.NewRouter()
	Api.ctx = ctx
	Api.ConnectorId = strings.Split(ConnectorID, ":")[0]
	Api.tunnelMu = &sync.RWMutex{}
	Api.tunnel = tun
	Api.mdCache = newMultiDomainCache("")
	Api.statusCache = newConnectorStatusCache("")
	// The refreshers look the tunnel up on every tick (not the value captured
	// here) so they follow SetTunnel in HA mode.
	tunState := &apiTunnelState{api: &Api}
	Api.mdCache.startRefresher(ctx, tunState)
	Api.statusCache.startRefresher(ctx, tunState)
	Api.cacheHistory = newCacheHistory(time.Now())
	Api.cacheHistory.startSampler(ctx)

	Api.commandChan = make(chan Message)
	Api.terminalActivity = &atomic.Int64{}
	Api.terminalSecret = &terminalSessionSecret{}
	Api.LogsEnabled = logsEnabled()
	Api.terminalRecording = terminalRecordingConfigFromEnv()
	var err error
	Api.TerminalEnabled, err = Api.terminal()
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error initializing terminal: %v", err))
	}
	if Api.TerminalEnabled {
		Api.terminalTOTPRequired = terminalTOTPRequired()
		if Api.terminalTOTPRequired {
			Api.terminalTOTP, err = newTerminalTOTP(ctx, Api.ConnectorId)
			if err != nil {
				// No usable seed means no terminal at all
				log.LoggerWContext(ctx).Error(fmt.Sprintf("Disabling the remote terminal: %v", err))
				Api.TerminalEnabled = false
			}
		} else {
			log.LoggerWContext(ctx).Warn("PFCONNECTOR_TERMINAL_TOTP is disabled: terminal activation only requires the one-time session uuid")
		}
	}

	Api.setupRoutes()

	return &Api
}

func (api *API) setupRoutes() {
	api.Router.Use(middleware.RequestID)
	// NOTE: do NOT use middleware.RealIP here. It rewrites r.RemoteAddr from
	// the X-Forwarded-For/X-Real-IP request headers, which a remote caller can
	// forge. localhostOnly relies on the real TCP peer in r.RemoteAddr to gate
	// this :8081 API to loopback; trusting proxy headers would let a remote
	// client spoof 127.0.0.1 and reach the service-management/credcache endpoints.
	api.Router.Use(middleware.Logger)
	api.Router.Use(middleware.Recoverer)

	api.Router.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Origin, Content-Type, Accept, Authorization, Upgrade, Connection, Sec-WebSocket-Key, Sec-WebSocket-Version, Sec-WebSocket-Protocol")

			if r.Method == "OPTIONS" {
				w.WriteHeader(http.StatusOK)
				return
			}

			next.ServeHTTP(w, r)
		})
	})

	// Reverse proxy in front of the local gotty terminal server
	gottyURL, err := url.Parse("http://localhost:8022")
	if err != nil {
		log.LoggerWContext(api.ctx).Error(fmt.Sprintf("Error parsing gotty URL: %v", err))
	}

	gottyProxy := httputil.NewSingleHostReverseProxy(gottyURL)
	originalDirector := gottyProxy.Director
	gottyProxy.Director = func(req *http.Request) {
		originalDirector(req)
		req.Host = gottyURL.Host

		if strings.ToLower(req.Header.Get("Upgrade")) == "websocket" {
			req.Header.Set("X-Forwarded-Proto", "http")
			req.Header.Set("X-Forwarded-Host", req.Host)
			req.Header.Set("Origin", "http://"+gottyURL.Host)
		}
	}
	gottyProxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.LoggerWContext(api.ctx).Error(fmt.Sprintf("Terminal proxy error: %v", err))
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusBadGateway)
		w.Write([]byte("The terminal is temporarily unavailable. Please try again in a few moments."))
	}

	api.Router.Route("/api/v1", func(r chi.Router) {
		r.Group(func(r chi.Router) {
			r.Use(localhostOnly)

			// Only the websocket of the terminal: the page and its assets
			// are served by the pfconnector server's API. It requires the
			// secret of the current session, generated by enableTerminal.
			r.HandleFunc("/terminal/ws", func(w http.ResponseWriter, r *http.Request) {
				if !api.terminalSecret.valid(r.Header.Get(terminalSecretHeader)) {
					http.Error(w, "No authorized terminal session", http.StatusForbidden)
					return
				}
				if !strings.EqualFold(r.Header.Get("Upgrade"), "websocket") {
					http.Error(w, "Only websocket requests are accepted", http.StatusBadRequest)
					return
				}
				r.Header.Del(terminalSecretHeader)
				r.URL.Path = "/ws"
				r.URL.RawPath = ""
				gottyProxy.ServeHTTP(w, r)
			})

			// NTLM authentication services of the host (see host_services.go):
			// the state comes from the host, the actions go to it through the
			// trigger file, hence the 202 answers.
			r.Route("/service", func(r chi.Router) {
				r.Get("/status", hostServicesStatus(api))
				r.Post("/status", hostServicesStatus(api))
				r.Get("/ping", ping(api))
				r.Post("/start", hostServiceAction(api, "start"))
				r.Post("/stop", hostServiceAction(api, "stop"))
				r.Post("/restart", hostServiceAction(api, "restart"))
			})
			r.Post("/radius/authorize", radiusAuthorize(api))
			r.Post("/radius/multi-domain/authorize", multiDomainAuthorize(api))
			r.Handle("/credcache/*", credcacheProxy())
			r.Handle("/credcache", credcacheProxy())
			r.Route("/system", func(r chi.Router) {
				r.Get("/info", systemInfo(api))
				r.Post("/restart", systemRestart(api))
				r.Post("/upgrade", systemUpgrade(api))
				r.Post("/install", systemInstall(api))
			})
			r.Get("/logs/{name}", tailLog(api))
			r.Post("/ha/switch", haSwitch(api))
			r.Get("/ha/status", haStatusHandler(api))
			// Management of the local connector-cache service (see cache.go).
			mountCacheRoutes(r, api)
			// Terminal session recordings (see terminal_recordings.go).
			mountTerminalRecordingRoutes(r, api)
			// Terminal activation, called by the pfconnector server's API
			// through the tunnel (one-time uuid check via remote-terminal,
			// then the TOTP code).
			r.Get("/authorize/{id}", enableTerminal(api))
		})
		// Not localhost-only: the backup hosts of an HA group post their
		// heartbeat to the master on the VIP (HMAC-authenticated, see ha.go).
		r.Post("/ha/heartbeat", haHeartbeat(api))
		r.Post("/ha/boost", haBoost(api))
		r.Get("/ha/cache-snapshot", haCacheSnapshot(api))
		r.Get("/ha/totp-seed", haTOTPSeed(api))
		r.Get("/ha/config-relay", haConfigRelay(api))
	})
}

// totpCodeHeader carries the TOTP code (mirrors the pfconnector-server's
// TOTPCodeHeader).
const totpCodeHeader = "X-PF-TOTP-Code"

// adminUserHeader carries the PacketFence admin username activating a
// terminal session (mirrors the server's AdminUserHeader); it labels the
// session's recordings.
const adminUserHeader = "X-PF-Admin-User"

// terminalActivationClient bounds the session check through the tunnel: the
// activation endpoint is reachable on the LAN, so a stalled tunnel must not
// let callers pile up hung handlers.
var terminalActivationClient = &http.Client{Timeout: 10 * time.Second}

// enableTerminal validates the one-time terminal session id against the
// pfconnector server (through the tunnel-local 22226 bind) and starts the
// gotty terminal. The authorized duration is an idle timeout: the terminal
// stays up as long as the user types and stops once it has been idle for
// that long.
func enableTerminal(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		if !api.TerminalEnabled {
			http.Error(res, "The remote terminal is not enabled on this connector", http.StatusForbidden)
			return
		}
		id := chi.URLParam(req, "id")
		if id == "" {
			http.Error(res, "Missing terminal ID", http.StatusBadRequest)
			return
		}

		query := url.Values{"connectorid": {api.ConnectorId}, "id": {id}}
		check, err := http.NewRequestWithContext(req.Context(), http.MethodGet, "http://127.0.0.1:22226/api/v1/pfconnector/remote-terminal?"+query.Encode(), nil)
		if err != nil {
			http.Error(res, fmt.Sprintf("Failed to enable terminal: %v", err), http.StatusInternalServerError)
			return
		}
		haStatusMu.RLock()
		connectorSecret := haConnectorSecret
		haStatusMu.RUnlock()
		check.Header.Set(connauth.Header, connauth.Sign(api.ConnectorId, connectorSecret, time.Now()))
		r, err := terminalActivationClient.Do(check)
		if err != nil {
			http.Error(res, fmt.Sprintf("Failed to enable terminal: %v", err), http.StatusInternalServerError)
			return
		}
		defer r.Body.Close()
		if r.StatusCode != http.StatusOK {
			http.Error(res, fmt.Sprintf("Failed to enable terminal: %s", r.Status), http.StatusInternalServerError)
			return
		}
		var j map[string]interface{}
		json.NewDecoder(r.Body).Decode(&j)
		if j["authorized"] != true {
			http.Error(res, "Terminal not authorized", http.StatusForbidden)
			return
		}

		// Second factor: the 6-digit TOTP code, validated against the seed
		// stored on this box. The one-time session uuid was already consumed
		// above, so every code guess costs a fresh session on the server.
		// Skipped only when PFCONNECTOR_TERMINAL_TOTP is explicitly disabled.
		if api.terminalTOTPRequired {
			second := api.currentTerminalTOTP()
			if second == nil {
				http.Error(res, "Terminal TOTP is not initialized", http.StatusForbidden)
				return
			}
			// The code comes in a header (query strings end up in access
			// logs); the query is accepted from older servers.
			code := req.Header.Get(totpCodeHeader)
			if code == "" {
				code = req.URL.Query().Get("code")
			}
			if err := second.validate(code); err != nil {
				status := http.StatusForbidden
				if errors.Is(err, errTOTPLocked) {
					status = http.StatusTooManyRequests
				}
				log.LoggerWContext(api.ctx).Warn(fmt.Sprintf("Refused terminal activation for session %s: %v", id, err))
				http.Error(res, err.Error(), status)
				return
			}
		}

		timeout := 360 * time.Second
		if t, ok := j["timeout"].(string); ok && t != "" {
			if d, err := time.ParseDuration(t); err == nil {
				timeout = d
			} else if secs, err := strconv.Atoi(t); err == nil {
				timeout = time.Duration(secs) * time.Second
			}
		}
		// Idle timeout: only the user's input resets the clock; the terminal
		// is stopped after `timeout` without any. Start the clock now so an
		// untouched session still expires. The lifecycle goroutine
		// (terminal.go) runs the one idle watcher of the running terminal; an
		// activation while it runs only re-arms it.
		api.terminalActivity.Store(time.Now().UnixNano())

		// The admin who activates the session, relayed by the PacketFence
		// server (never trusted for anything but labelling the recording).
		adminUser := strings.TrimSpace(req.Header.Get(adminUserHeader))

		// A new secret per authorized session: the previous session, if
		// any, can't reach the terminal anymore.
		secret, err := api.terminalSecret.renew()
		if err != nil {
			http.Error(res, "Failed to create the terminal session", http.StatusInternalServerError)
			return
		}

		select {
		case api.commandChan <- Message{Type: StartProcessing, Session: id, AdminUser: adminUser, IdleTimeout: timeout}:
			log.LoggerWContext(api.ctx).Info("Terminal start command sent successfully")
		case <-time.After(time.Second * 5):
			api.terminalSecret.clear()
			http.Error(res, "Timeout sending start command", http.StatusInternalServerError)
			return
		}

		res.Header().Set("Content-Type", "application/json")
		res.WriteHeader(http.StatusOK)
		json.NewEncoder(res).Encode(map[string]string{"message": "Terminal is enabled", "secret": secret})
	})
}

// credcacheProxy forwards every request under /api/v1/credcache to the URL
// in CREDCACHE_URL (default: local connector-cache REST endpoint).
// Used so callers reaching the pfconnector-client API can push/fetch
// nt_key cache rows without knowing where connector-cache actually lives.
func credcacheProxy() http.HandlerFunc {
	targetStr := strings.TrimSpace(os.Getenv("CREDCACHE_URL"))
	if targetStr == "" {
		targetStr = defaultCredcacheTarget
	}
	target, err := url.Parse(targetStr)
	if err != nil || target.Scheme == "" || target.Host == "" {
		return func(w http.ResponseWriter, r *http.Request) {
			http.Error(w, fmt.Sprintf("invalid CREDCACHE_URL %q", targetStr), http.StatusInternalServerError)
		}
	}
	proxy := &httputil.ReverseProxy{
		Director: func(req *http.Request) {
			suffix := strings.TrimPrefix(req.URL.Path, credcacheRoutePrefix)
			req.URL.Scheme = target.Scheme
			req.URL.Host = target.Host
			req.URL.Path = singleJoiningSlash(target.Path, suffix)
			if target.RawQuery == "" || req.URL.RawQuery == "" {
				req.URL.RawQuery = target.RawQuery + req.URL.RawQuery
			} else {
				req.URL.RawQuery = target.RawQuery + "&" + req.URL.RawQuery
			}
			req.Host = target.Host
			if _, ok := req.Header["User-Agent"]; !ok {
				req.Header.Set("User-Agent", "")
			}
		},
	}
	return proxy.ServeHTTP
}

func singleJoiningSlash(a, b string) string {
	aSlash := strings.HasSuffix(a, "/")
	bSlash := strings.HasPrefix(b, "/")
	switch {
	case aSlash && bSlash:
		return a + b[1:]
	case !aSlash && !bSlash:
		if a == "" {
			return b
		}
		if b == "" {
			return a
		}
		return a + "/" + b
	}
	return a + b
}

func localhostOnly(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Extraire l'IP de la requête
		ip := r.RemoteAddr
		if host, _, err := net.SplitHostPort(ip); err == nil {
			ip = host
		}

		// Vérifier si c'est localhost
		if ip != "127.0.0.1" && ip != "::1" {
			http.Error(w, "Access denied", http.StatusForbidden)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func (api *API) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Serve the request using the chi router
	api.Router.ServeHTTP(w, r)
}

// ping to test if the connector is running
func ping(_ *API) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, _ *http.Request) {
		res.Header().Set("Content-Type", "text/plain; charset=utf-8")
		res.WriteHeader(http.StatusOK)
		res.Write([]byte("pong"))
	})
}

// hostUserNameRegex matches the host-style user name
// "host/<shortname>.<realm>" used by machine auth. Compiled once.
var hostUserNameRegex = regexp.MustCompile(`^host/([0-9a-zA-Z-_]+)\.(.*)$`)

// rlmRestAttr models a single attribute in an rlm_rest request/response body.
// rlm_rest encodes attributes as objects with at least a "value" array.
type rlmRestAttr struct {
	Type  string   `json:"type,omitempty"`
	Value []string `json:"value"`
}

// firstValue returns the first element of the attribute's value array, or "".
func (a *rlmRestAttr) firstValue() string {
	if a == nil || len(a.Value) == 0 {
		return ""
	}
	return a.Value[0]
}

// stripUserName returns the user portion of userName with the realm stripped,
// mirroring what FreeRADIUS suffix/ntdomain modules would set as
// Stripped-User-Name. Machine accounts (host/…) are returned unchanged because
// their realm is embedded in the FQDN and ntlm_auth expects the full name.
//
// Returns an empty string when no stripping applies (same as userName would
// mean no change, so callers should check != userName before using).
func stripUserName(userName string) string {
	// Machine account host/<shortname>.<realm> — do not strip
	if hostUserNameRegex.MatchString(userName) {
		return ""
	}
	// IPASS prefix: realm/username → username
	if idx := strings.Index(userName, "/"); idx >= 0 {
		return userName[idx+1:]
	}
	// suffix "@": username@realm → username
	if idx := strings.LastIndex(userName, "@"); idx >= 0 {
		return userName[:idx]
	}
	// realmpercent "%": username%realm → username
	if idx := strings.LastIndex(userName, "%"); idx >= 0 {
		return userName[:idx]
	}
	// ntdomain "\": domain\username → username
	if idx := strings.Index(userName, `\`); idx >= 0 {
		return userName[idx+1:]
	}
	return ""
}

// extractRealm derives the effective realm from a FreeRADIUS request,
// replicating the order in which FreeRADIUS realm modules and the
// packetfence-set-realm-if-machine policy set the Realm attribute:
//
//  1. Explicit Realm attribute already present in the request body.
//  2. packetfence-set-realm-if-machine: host/<name>.<realm> → <realm>
//  3. IPASS (prefix "/"): realm/username → realm
//  4. suffix "@" (ignore_null): username@realm → realm
//  5. realmpercent (suffix "%"): username%realm → realm
//  6. ntdomain (prefix "\"): domain\username → domain
//
// Returns an empty string when none of the rules match.
func extractRealm(userName, realmAttr string) string {
	if realmAttr != "" {
		return realmAttr
	}
	if matches := hostUserNameRegex.FindStringSubmatch(userName); matches != nil {
		// Machine account: host/<shortname>.<realm> → realm suffix.
		return matches[2]
	}
	if idx := strings.Index(userName, "/"); idx >= 0 {
		// IPASS prefix: realm/username
		return userName[:idx]
	}
	if idx := strings.LastIndex(userName, "@"); idx >= 0 {
		// suffix: username@realm (ignore_null handled by idx >= 0 guard)
		return userName[idx+1:]
	}
	if idx := strings.LastIndex(userName, "%"); idx >= 0 {
		// realmpercent suffix: username%realm
		return userName[idx+1:]
	}
	if idx := strings.Index(userName, `\`); idx >= 0 {
		// ntdomain prefix: domain\username
		return userName[:idx]
	}
	return ""
}

// lookupRealmKey resolves the request's User-Name / Realm to a realm key
// from cfg.Realms, mirroring the order FreeRADIUS realm modules apply:
// exact match, lowercase match, ordered regex fallback, then "default" if
// configured. Returns "" when nothing matches. Shared by multiDomainAuthorize
// and radiusAuthorize so they reach the same realm decision.
func lookupRealmKey(cfg *multiDomainConfig, regexes map[string]*regexp.Regexp, userName, realmAttr string) string {
	effectiveRealm := extractRealm(userName, realmAttr)
	if effectiveRealm != "" {
		if _, ok := cfg.Realms[effectiveRealm]; ok {
			return effectiveRealm
		}
		if lower := strings.ToLower(effectiveRealm); lower != effectiveRealm {
			if _, ok := cfg.Realms[lower]; ok {
				return lower
			}
		}
	}
	if _, hasDefault := cfg.Realms["default"]; !hasDefault {
		return ""
	}
	for _, key := range cfg.OrderedRealms {
		re, ok := regexes[key]
		if !ok {
			continue
		}
		if re.MatchString(userName) {
			return key
		}
	}
	return "default"
}

// connectorForRequest derives the connector_id that owns the AD for the
// realm carried by the rlm_rest body. Returns ("", false) when the request
// has no body, the realm doesn't map to a domain, or the domain has no
// configured connector. Used by radiusAuthorize to short-circuit to
// degraded when that connector is unreachable.
func connectorForRequest(api *API, r *http.Request) (string, bool) {
	if api == nil || api.mdCache == nil {
		return "", false
	}
	cfg, regexes := api.mdCache.get()
	if cfg == nil {
		return "", false
	}
	req := map[string]*rlmRestAttr{}
	if r.Body != nil {
		_ = json.NewDecoder(r.Body).Decode(&req)
	}
	userName := req["TLS-Client-Cert-Common-Name"].firstValue()
	if userName == "" {
		userName = req["User-Name"].firstValue()
	}
	realmAttr := req["Realm"].firstValue()

	realmKey := lookupRealmKey(cfg, regexes, userName, realmAttr)
	if realmKey == "" {
		return "", false
	}
	rc, ok := cfg.Realms[realmKey]
	if !ok || rc.Domain == "" {
		return "", false
	}
	connectorID, ok := cfg.DomainConnector[rc.Domain]
	if !ok || connectorID == "" {
		return "", false
	}
	return connectorID, true
}

// multiDomainAuthorize is a Go port of
// raddb/mods-config/perl/packetfence-multi-domain.pm::authorize.
//
// It reads User-Name / TLS-Client-Cert-Common-Name / Realm from an rlm_rest
// JSON request, resolves the configured realm and domain using the cached
// multi-domain config, and returns an rlm_rest response setting
// PacketFence-Domain, PacketFence-NTLM-Auth-Host and PacketFence-NTLM-Auth-Port
// on the request list (same list the Perl %RAD_REQUEST writes to).
//
// If no realm maps, returns an empty JSON object so FreeRADIUS proceeds
// without multi-domain attributes (mirrors the Perl fall-through behavior).
func multiDomainAuthorize(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")

		reply := map[string]interface{}{}

		cfg, regexes := api.mdCache.get()
		if cfg == nil {
			// Cache is empty (first fetch hasn't succeeded yet or tunnel is down).
			// Fall through without setting any attributes.
			w.WriteHeader(http.StatusOK)
			json.NewEncoder(w).Encode(reply)
			return
		}

		req := map[string]*rlmRestAttr{}
		if r.Body != nil {
			_ = json.NewDecoder(r.Body).Decode(&req)
		}

		userName := req["TLS-Client-Cert-Common-Name"].firstValue()
		if userName == "" {
			userName = req["User-Name"].firstValue()
		}
		realmAttr := req["Realm"].firstValue()

		realmKey := lookupRealmKey(cfg, regexes, userName, realmAttr)

		if realmKey == "" {
			w.WriteHeader(http.StatusOK)
			json.NewEncoder(w).Encode(reply)
			return
		}

		realmCfg := cfg.Realms[realmKey]
		if realmCfg.Domain == "" {
			w.WriteHeader(http.StatusOK)
			json.NewEncoder(w).Encode(reply)
			return
		}

		reply["request:PacketFence-Domain"] = map[string]interface{}{
			"op":    ":=",
			"value": []string{realmCfg.Domain},
		}

		// Provide Stripped-User-Name so FreeRADIUS ntlm_auth gets just the
		// username (e.g. "fdurand") even when no realm is configured locally
		// and the suffix module returns noop.
		if stripped := stripUserName(userName); stripped != "" {
			reply["request:Stripped-User-Name"] = map[string]interface{}{
				"op":    ":=",
				"value": []string{stripped},
			}
		}

		if domainCfg, ok := cfg.Domains[realmCfg.Domain]; ok {
			reply["request:PacketFence-NTLM-Auth-Host"] = map[string]interface{}{
				"op":    ":=",
				"value": []string{domainCfg.NtlmAuthHost},
			}
			port := domainCfg.NtlmAuthPort
			if portNum, err := strconv.Atoi(domainCfg.NtlmAuthPort); err == nil {
				port = strconv.Itoa(portNum)
			}
			reply["request:PacketFence-NTLM-Auth-Port"] = map[string]interface{}{
				"op":    ":=",
				"value": []string{port},
			}
		}

		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(reply)
	})
}

// radiusAuthorize returns control:Proxy-To-Realm based on tunnel connectivity.
// Used by rlm_rest in the FreeRADIUS authorize section.
//
// "remote" means forward this request to cloud RADIUS via the chisel tunnel;
// "degraded" keeps the request local (credcache-backed PEAP/TTLS, or local
// EAP-TLS, both of which work without reaching AD). We pick degraded when:
//
//  1. our own tunnel is down — cloud RADIUS is unreachable, or
//  2. the cloud could be reached but the connector that owns the AD for
//     this realm is unreachable on the server side. ntlm_auth_api_remote
//     would be unavailable there, so cloud RADIUS would just time out;
//     degraded is strictly better.
//
// EAP-Type isn't visible at authorize time; degraded is safe across PEAP,
// TTLS and TLS — see go/chisel/clientapi/connector_status.go for the
// reasoning.
func radiusAuthorize(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")

		realm := "degraded"
		if api.TunnelActive() {
			realm = "remote"
			if api.statusCache != nil {
				if connectorID, ok := connectorForRequest(api, r); ok {
					if up, known := api.statusCache.isUp(connectorID); known && !up {
						realm = "degraded"
					}
				}
			}
		}

		w.WriteHeader(http.StatusOK)
		response := map[string]interface{}{
			"control:Proxy-To-Realm": map[string]interface{}{
				"op":    ":=",
				"value": []string{realm},
			},
		}
		json.NewEncoder(w).Encode(response)
	})
}

// Start starts the API server
func (api *API) Start(ctx context.Context, addr string) error {
	server := &http.Server{
		Addr:    addr,
		Handler: api,
	}

	// This is an auxiliary side-car API (status/credcache/service control). A
	// listen failure (e.g. port already bound on a restart race) must not take
	// down the pfconnector-client process with it, so log and return rather
	// than panic.
	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Logger().Error(fmt.Sprintf("clientapi: server on %s stopped: %s", addr, err))
		}
	}()

	// Wait for the context to be done
	<-ctx.Done()

	// Shutdown the server gracefully. The incoming ctx is already cancelled, so
	// use a fresh bounded context to give in-flight requests a chance to drain.
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	return server.Shutdown(shutdownCtx)
}
