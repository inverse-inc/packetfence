package apiaaa

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"time"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/go-utils/statsd"
	"github.com/inverse-inc/packetfence/go/api-frontend/aaa"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2"
	"github.com/julienschmidt/httprouter"
)

// Register the plugin in caddy
func init() {
	caddy.RegisterModule(ApiAAAHandler{})
	httpcaddyfile.RegisterHandlerDirective("api-aaa", caddy2.ParseCaddyfile[ApiAAAHandler])
}

type PrettyTokenInfo struct {
	AdminActions []string  `json:"admin_actions"`
	AdminRoles   []string  `json:"admin_roles"`
	Username     string    `json:"username"`
	ExpiresAt    time.Time `json:"expires_at"`
}

type ApiAAAHandler struct {
	caddy2.ModuleBase
	router             *httprouter.Router
	systemBackend      *aaa.MemAuthenticationBackend
	webservicesBackend *aaa.MemAuthenticationBackend
	authentication     *aaa.TokenAuthenticationMiddleware
	authorization      *aaa.TokenAuthorizationMiddleware
	NoAuthPaths        map[string]bool `json:"no_auth_paths"`
	SessionBackend     []string        `json:"session_backend"`
}

// Setup the api-aaa middleware
// Also loads the pfconfig resources and registers them in the pool
func (h *ApiAAAHandler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {

	noAuthPaths := map[string]bool{}
	tokenBackendArgs := []string{}
	for c.Next() {
		for nesting := c.Nesting(); c.NextBlock(nesting); {
			switch c.Val() {
			case "no_auth":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				} else {
					path := args[0]
					noAuthPaths[path] = true
					fmt.Println("The following path will not be authenticated via the api-aaa module", path)
				}
			case "session_backend":
				tokenBackendArgs = c.RemainingArgs()

				if len(tokenBackendArgs) == 0 {
					return c.ArgErr()
				}

			default:
				return c.ArgErr()
			}
		}
	}

	h.NoAuthPaths = noAuthPaths
	h.SessionBackend = tokenBackendArgs

	return nil
}

func hasDuplicate(a []string) bool {
	dups := map[string]struct{}{}
	for _, i := range a {
		if _, found := dups[i]; found {
			return true
		}
		dups[i] = struct{}{}
	}
	return false
}

func validateTokenArgs(args []string) error {
	if hasDuplicate(args) {
		return errors.New("Cannot defined a backend type multiple times")
	}

	for _, i := range args {
		switch i {
		default:
			err := fmt.Errorf("Invalid session_backend type '%s'", i)
			return err
		case "mem", "redis", "db":
			break
		}
	}

	return nil
}

// Build the ApiAAAHandler which will initialize the cache and instantiate the router along with its routes
func (h *ApiAAAHandler) buildApiAAAHandler(ctx context.Context) error {

	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Webservices)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.UnifiedApiSystemUser)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.AdminRoles)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Advanced)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.ServicesURL)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.AdminLogin)

	tokenBackend := aaa.MakeTokenBackend(h.SessionBackend)
	h.authentication = aaa.NewTokenAuthenticationMiddleware(tokenBackend)

	// Backend for the system Unified API user
	if pfconfigdriver.Config.UnifiedApiSystemUser.User != "" {
		h.systemBackend = aaa.NewMemAuthenticationBackend(
			map[string]string{},
			map[string]bool{"ALL": true},
		)
		h.systemBackend.SetUser(pfconfigdriver.Config.UnifiedApiSystemUser.User, pfconfigdriver.Config.UnifiedApiSystemUser.Pass)
		h.authentication.AddAuthenticationBackend(h.systemBackend)
	} else {
		panic("Unable to setup the system user authentication backend")
	}

	// Backend for the pf.conf webservices user
	h.webservicesBackend = aaa.NewMemAuthenticationBackend(
		map[string]string{},
		map[string]bool{"ALL": true},
	)
	h.authentication.AddAuthenticationBackend(h.webservicesBackend)

	if pfconfigdriver.Config.PfConf.Webservices.User != "" {
		h.webservicesBackend.SetUser(pfconfigdriver.Config.PfConf.Webservices.User, pfconfigdriver.Config.PfConf.Webservices.Pass)
	}

	// Backend for SSO
	if sharedutils.IsEnabled(pfconfigdriver.Config.PfConf.AdminLogin.SSOStatus) {
		url, err := url.Parse(fmt.Sprintf("%s%s", pfconfigdriver.Config.PfConf.AdminLogin.SSOBaseUrl, pfconfigdriver.Config.PfConf.AdminLogin.SSOAuthorizePath))
		sharedutils.CheckError(err)
		h.authentication.AddAuthenticationBackend(aaa.NewPortalAuthenticationBackend(ctx, url, false))
	}

	// Backend for username/password auth via the internal auth sources
	if sharedutils.IsEnabled(pfconfigdriver.Config.PfConf.AdminLogin.AllowUsernamePassword) {
		url, err := url.Parse(fmt.Sprintf("%s/api/v1/authentication/admin_authentication", pfconfigdriver.Config.PfConf.ServicesURL.PfperlApi))
		sharedutils.CheckError(err)
		h.authentication.AddAuthenticationBackend(aaa.NewPfAuthenticationBackend(ctx, url, false))
	}

	h.authorization = aaa.NewTokenAuthorizationMiddleware(tokenBackend)

	router := httprouter.New()
	router.POST("/api/v1/login", h.handleLogin)
	router.GET("/api/v1/token_info", h.handleTokenInfo)
	router.GET("/api/v1/sso_info", h.handleSSOInfo)

	h.router = router

	return nil
}

// Handle an API login
func (h ApiAAAHandler) handleLogin(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("api-aaa.login")

	var loginParams struct {
		Username string
		Password string
	}

	err := json.NewDecoder(r.Body).Decode(&loginParams)

	if err != nil {
		msg := fmt.Sprintf("Error while decoding payload: %s", err)
		log.LoggerWContext(ctx).Error(msg)
		http.Error(w, fmt.Sprint(err), http.StatusBadRequest)
		return
	}

	auth, token, err := h.authentication.Login(ctx, loginParams.Username, loginParams.Password)

	if auth {
		w.WriteHeader(http.StatusOK)
		res, _ := json.Marshal(map[string]string{
			"token": token,
		})
		fmt.Fprintf(w, string(res))
	} else {
		w.WriteHeader(http.StatusUnauthorized)
		res, _ := json.Marshal(map[string]string{
			"message": err.Error(),
		})
		fmt.Fprintf(w, string(res))
	}
}

// Handle getting the token info
func (h ApiAAAHandler) handleTokenInfo(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	defer statsd.NewStatsDTiming(ctx).Send("api-aaa.token_info")

	if r.URL.Query().Get("no-expiration-extension") == "" {
		h.authentication.TouchTokenInfo(ctx, r)
	}
	info, expiration := h.authorization.GetTokenInfoFromBearerRequest(ctx, r)

	if info != nil {
		// We'll want to render the roles as an array, not as a map
		prettyInfo := PrettyTokenInfo{
			AdminActions: make([]string, len(info.AdminActions())),
			AdminRoles:   make([]string, len(info.AdminRoles)),
			Username:     info.Username,
			ExpiresAt:    expiration,
		}

		i := 0
		for r, _ := range info.AdminActions() {
			prettyInfo.AdminActions[i] = r
			i++
		}

		i = 0
		for r, _ := range info.AdminRoles {
			prettyInfo.AdminRoles[i] = r
			i++
		}

		w.WriteHeader(http.StatusOK)
		res, _ := json.Marshal(map[string]interface{}{
			"item": prettyInfo,
		})
		fmt.Fprintf(w, string(res))
	} else {
		w.WriteHeader(http.StatusNotFound)
		res, _ := json.Marshal(map[string]string{
			"message": "Couldn't find any information for the current token. Either it is invalid or it has expired.",
		})
		fmt.Fprintf(w, string(res))
	}
}

func (h ApiAAAHandler) handleSSOInfo(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	info := struct {
		LoginText string `json:"login_text"`
		LoginURL  string `json:"login_url"`
		IsEnabled bool   `json:"is_enabled"`
	}{
		LoginText: pfconfigdriver.Config.PfConf.AdminLogin.SSOLoginText,
		LoginURL:  fmt.Sprintf("%s%s", pfconfigdriver.Config.PfConf.AdminLogin.SSOBaseUrl, pfconfigdriver.Config.PfConf.AdminLogin.SSOLoginPath),
		IsEnabled: sharedutils.IsEnabled(pfconfigdriver.Config.PfConf.AdminLogin.SSOStatus),
	}

	json.NewEncoder(w).Encode(info)
}

func (h ApiAAAHandler) HandleAAA(w http.ResponseWriter, r *http.Request) bool {
	if aaa.IsPathPublic(r.URL.Path) {
		return true
	}

	ctx := r.Context()
	auth, err := h.authentication.BearerRequestIsAuthorized(ctx, r)

	if !auth {
		w.WriteHeader(http.StatusUnauthorized)

		if err == nil {
			err = errors.New("Invalid token. Login again using /api/v1/login")
		}

		res, _ := json.Marshal(map[string]string{
			"message": err.Error(),
		})
		fmt.Fprintf(w, string(res))
		return false
	}

	h.authentication.TouchTokenInfo(ctx, r)

	auth, err = h.authorization.BearerRequestIsAuthorized(ctx, r)

	if auth {
		return true
	} else {
		if err.Error() == aaa.InvalidTokenInfoErr {
			w.WriteHeader(http.StatusUnauthorized)
		} else {
			w.WriteHeader(http.StatusForbidden)
		}
		res, _ := json.Marshal(map[string]string{
			"message": err.Error(),
		})
		fmt.Fprintf(w, string(res))
		return false
	}
}

func (h *ApiAAAHandler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	ctx := r.Context()

	// Reload the webservices user info
	if pfconfigdriver.Config.PfConf.Webservices.User != "" {
		h.webservicesBackend.SetUser(pfconfigdriver.Config.PfConf.Webservices.User, pfconfigdriver.Config.PfConf.Webservices.Pass)
	}

	defer panichandler.Http(ctx, w)

	defer func() {
		// We default to application/json if there is no content type
		if w.Header().Get("Content-Type") == "" {
			w.Header().Set("Content-Type", "application/json")
		}
	}()

	if handle, params, _ := h.router.Lookup(r.Method, r.URL.Path); handle != nil {
		handle(w, r, params)

		// TODO change me and wrap actions into something that handles server errors
		return nil
	} else {
		_, noauth := h.NoAuthPaths[r.URL.Path]
		if noauth || h.HandleAAA(w, r) {
			return next.ServeHTTP(w, r)
		} else {
			// TODO change me and wrap actions into something that handles server errors
			return nil
		}
	}

}

func (h *ApiAAAHandler) Validate() error {
	return validateTokenArgs(h.SessionBackend)
}

func (h *ApiAAAHandler) Provision(ctx caddy.Context) error {
	return h.buildApiAAAHandler(ctx)
}

func (h ApiAAAHandler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID:  "http.handlers.api-aaa",
		New: func() caddy.Module { return &ApiAAAHandler{} },
	}
}
