package clientapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/chisel/share/tunnel"
	systemdmanager "github.com/inverse-inc/packetfence/go/systemdmanager"
)

const credcacheRoutePrefix = "/api/v1/credcache"
const defaultCredcacheTarget = "http://127.0.0.1:12142/api/v1/credcache/"

// Handler struct
type API struct {
	Router          *chi.Mux
	ConnectorId     string
	TerminalEnabled bool
	ctx             context.Context
	cancel          context.CancelFunc
	tunnel          *tunnel.Tunnel
	mdCache         *multiDomainCache
	statusCache     *connectorStatusCache
	commandChan     chan Message
	serverRunning   int32
}

// MessageType is a command for the gotty terminal lifecycle goroutine.
type MessageType int

const (
	StartProcessing MessageType = iota
	StopProcessing
)

// Message carries a command for the terminal lifecycle goroutine.
type Message struct {
	Type MessageType
}

type Service struct {
	Name string `json:"service"`
}

func NewApi(ctx context.Context, ConnectorID string, tun *tunnel.Tunnel) API {
	Api := API{}
	Api.Router = chi.NewRouter()
	Api.ctx = ctx
	Api.ConnectorId = strings.Split(ConnectorID, ":")[0]
	Api.tunnel = tun
	Api.mdCache = newMultiDomainCache("")
	Api.statusCache = newConnectorStatusCache("")
	var tunState tunnelState
	if Api.tunnel != nil {
		tunState = Api.tunnel
	}
	Api.mdCache.startRefresher(ctx, tunState)
	Api.statusCache.startRefresher(ctx, tunState)

	Api.commandChan = make(chan Message)
	var err error
	Api.TerminalEnabled, err = Api.terminal()
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error initializing terminal: %v", err))
	}

	Api.setupRoutes()

	return Api
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

			r.HandleFunc("/terminal/*", func(w http.ResponseWriter, r *http.Request) {
				r.URL.Path = strings.TrimPrefix(r.URL.Path, "/api/v1/terminal")
				if r.URL.Path == "" {
					r.URL.Path = "/"
				}
				gottyProxy.ServeHTTP(w, r)
			})
			r.HandleFunc("/terminal", func(w http.ResponseWriter, r *http.Request) {
				http.Redirect(w, r, "/api/v1/terminal/", http.StatusMovedPermanently)
			})

			r.Route("/service", func(r chi.Router) {
				r.Post("/all", statusAll(api))
				r.Post("/status", status(api))
				r.Get("/ping", ping(api))
				r.Post("/start", manageService(api, "start"))
				r.Post("/stop", manageService(api, "stop"))
				r.Post("/restart", manageService(api, "restart"))
			})
			r.Post("/radius/authorize", radiusAuthorize(api))
			r.Post("/radius/multi-domain/authorize", multiDomainAuthorize(api))
			r.Handle("/credcache/*", credcacheProxy())
			r.Handle("/credcache", credcacheProxy())
		})
		// Not localhost-only: the admin's browser reaches this directly on
		// the remote's IP to activate a terminal session authorized by the
		// pfconnector server (one-time uuid check via remote-terminal).
		r.Get("/authorize/{id}", enableTerminal(api))
	})
}

// enableTerminal validates the one-time terminal session id against the
// pfconnector server (through the tunnel-local 22226 bind) and starts the
// gotty terminal for the authorized duration.
func enableTerminal(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		id := chi.URLParam(req, "id")
		if id == "" {
			http.Error(res, "Missing terminal ID", http.StatusBadRequest)
			return
		}

		r, err := http.Get(fmt.Sprintf("http://127.0.0.1:22226/api/v1/pfconnector/remote-terminal?connectorid=%s&id=%s", api.ConnectorId, id))
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

		timeout := 360 * time.Second
		if t, ok := j["timeout"].(string); ok && t != "" {
			if d, err := time.ParseDuration(t); err == nil {
				timeout = d
			} else if secs, err := strconv.Atoi(t); err == nil {
				timeout = time.Duration(secs) * time.Second
			}
		}
		go func(timeout time.Duration) {
			// Stop the terminal once the authorized duration has elapsed
			time.Sleep(timeout)
			api.commandChan <- Message{Type: StopProcessing}
		}(timeout)

		select {
		case api.commandChan <- Message{Type: StartProcessing}:
			log.LoggerWContext(api.ctx).Info("Terminal start command sent successfully")
		case <-time.After(time.Second * 5):
			http.Error(res, "Timeout sending start command", http.StatusInternalServerError)
			return
		}

		res.Header().Set("Content-Type", "application/json")
		res.WriteHeader(http.StatusOK)
		res.Write([]byte(`{"message": "Terminal is enabled"}`))
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

// status handles the status endpoint
func status(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		var srv Service
		if err := json.NewDecoder(req.Body).Decode(&srv); err != nil {
			http.Error(res, err.Error(), http.StatusBadRequest)
			return
		}

		if srv.Name == "" {
			http.Error(res, "Service name is required (packetfence-fingerbank-collector.service, packetfence-ntlm-auth-api-remote.service, packetfence-ntlm-join-remote.service, packetfence-pfconnector-remote-combined.service)", http.StatusBadRequest)
			return
		}

		systemd, err := systemdmanager.NewSystemdManager()
		if err != nil {
			http.Error(res, fmt.Sprintf("Failed to create systemd manager: %v", err), http.StatusInternalServerError)
			return
		}
		defer systemd.Close()
		allowed := []string{"packetfence-fingerbank-collector.service", "packetfence-ntlm-auth-api-remote.service", "packetfence-ntlm-join-remote.service", "packetfence-pfconnector-remote-combined.service"}
		for _, service := range allowed {
			if srv.Name == service {
				status, substatus, err := systemd.Status(service)
				if err != nil {
					http.Error(res, fmt.Sprintf("Failed to get service status: %v", err), http.StatusNotFound)
					return
				}
				res.Header().Set("Content-Type", "application/json")
				res.WriteHeader(http.StatusOK)
				json.NewEncoder(res).Encode(map[string]string{
					"service":   srv.Name,
					"status":    status,
					"substatus": substatus,
				})
				return

			}
		}
		http.Error(res, fmt.Sprintf("Service %s is not allowed", srv.Name), http.StatusForbidden)
	})
}

func statusAll(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		systemd, err := systemdmanager.NewSystemdManager()
		if err != nil {
			http.Error(res, fmt.Sprintf("Failed to create systemd manager: %v", err), http.StatusInternalServerError)
			return
		}
		defer systemd.Close()

		services, err := systemd.ListSystemdServices()
		if err != nil {
			http.Error(res, fmt.Sprintf("Failed to list services: %v", err), http.StatusInternalServerError)
			return
		}
		res.Header().Set("Content-Type", "application/json")
		res.WriteHeader(http.StatusOK)
		response := make([]map[string]string, len(services))
		for i, service := range services {
			response[i] = map[string]string{
				"name":         service.Name,
				"description":  service.Description,
				"load_state":   service.LoadState,
				"active_state": service.ActiveState,
				"sub_state":    service.SubState,
			}
		}
		jsonResponse, err := json.Marshal(response)
		if err != nil {
			http.Error(res, fmt.Sprintf("Failed to marshal response: %v", err), http.StatusInternalServerError)
			return
		}
		res.Write(jsonResponse)
	})
}

// start handles the start endpoint
func manageService(api *API, action string) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		var srv Service
		if err := json.NewDecoder(req.Body).Decode(&srv); err != nil {
			http.Error(res, err.Error(), http.StatusBadRequest)
			return
		}

		if srv.Name == "" {
			http.Error(res, "Service name is required (packetfence-fingerbank-collector.service, packetfence-ntlm-auth-api-remote.service, packetfence-ntlm-join-remote.service, packetfence-pfconnector-remote-combined.service)", http.StatusBadRequest)
			return
		}

		systemd, err := systemdmanager.NewSystemdManager()
		if err != nil {
			http.Error(res, fmt.Sprintf("Failed to create systemd manager: %v", err), http.StatusInternalServerError)
			return
		}
		defer systemd.Close()
		allowed := []string{"packetfence-fingerbank-collector.service", "packetfence-ntlm-auth-api-remote.service", "packetfence-ntlm-join-remote.service", "packetfence-pfconnector-remote-combined.service"}
		for _, service := range allowed {
			if srv.Name == service {
				switch action {
				case "start":
					if err := systemd.Start(srv.Name); err != nil {
						http.Error(res, fmt.Sprintf("Failed to start service %s: %v", srv.Name, err), http.StatusInternalServerError)
						return
					}
					res.WriteHeader(http.StatusOK)
					res.Write([]byte(fmt.Sprintf("Service %s started successfully", srv.Name)))
					return
				case "stop":
					if err := systemd.Stop(srv.Name); err != nil {
						http.Error(res, fmt.Sprintf("Failed to stop service %s: %v", srv.Name, err), http.StatusInternalServerError)
						return
					}
					res.WriteHeader(http.StatusOK)
					res.Write([]byte(fmt.Sprintf("Service %s stopped successfully", srv.Name)))
					return
				case "restart":
					if err := systemd.Restart(srv.Name); err != nil {
						http.Error(res, fmt.Sprintf("Failed to restart service %s: %v", srv.Name, err), http.StatusInternalServerError)
						return
					}
					res.WriteHeader(http.StatusOK)
					res.Write([]byte(fmt.Sprintf("Service %s restarted successfully", srv.Name)))
					return
				default:
					http.Error(res, "Invalid action specified", http.StatusBadRequest)
					return

				}
			}
		}
		http.Error(res, fmt.Sprintf("Service %s is not allowed", srv.Name), http.StatusForbidden)
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
		if api.tunnel != nil && api.tunnel.IsActive() {
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
