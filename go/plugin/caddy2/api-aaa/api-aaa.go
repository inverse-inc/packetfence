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
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
	"github.com/julienschmidt/httprouter"
)

// Register the plugin in caddy
func init() {
	caddy.RegisterModule(ApiAAAHandler{})
	httpcaddyfile.RegisterHandlerDirective("api-aaa", utils.ParseCaddyfile[ApiAAAHandler])
}

// CaddyModule returns the Caddy module information.
func (ApiAAAHandler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.api-aaa",
		New: func() caddy.Module {
			return &ApiAAAHandler{}
		},
	}
}

type PrettyTokenInfo struct {
	AdminActions []string  `json:"admin_actions"`
	AdminRoles   []string  `json:"admin_roles"`
	Username     string    `json:"username"`
	ExpiresAt    time.Time `json:"expires_at"`
}

type ApiAAAHandler struct {
	router             *httprouter.Router                 `json:"-"`
	systemBackend      *aaa.MemAuthenticationBackend      `json:"-"`
	webservicesBackend *aaa.MemAuthenticationBackend      `json:"-"`
	authentication     *aaa.TokenAuthenticationMiddleware `json:"-"`
	authorization      *aaa.TokenAuthorizationMiddleware  `json:"-"`
	NoAuthPaths        map[string]bool                    `json:"no_auth_paths"`
	TokenBackend       []string                           `json:"token_backend"`
}

// Setup the api-aaa middleware
// Also loads the pfconfig resources and registers them in the pool
func (s *ApiAAAHandler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {

	noAuthPaths := map[string]bool{}
	tokenBackendArgs := []string{}
	var err error
	for c.Next() {
		for c.NextBlock(0) {
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
				args := c.RemainingArgs()

				if len(args) == 0 {
					return c.ArgErr()
				}

				tokenBackendArgs, err = validateTokenArgs(args)
				if err != nil {
					return err
				}

			default:
				return c.ArgErr()
			}
		}
	}

	s.NoAuthPaths = noAuthPaths
	s.TokenBackend = tokenBackendArgs
	return nil
}

func (m *ApiAAAHandler) Provision(_ caddy.Context) error {
	ctx := log.LoggerNewContext(context.Background())
	err := m.buildApiAAAHandler(ctx)

	if err != nil {
		return err
	}

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

func validateTokenArgs(args []string) ([]string, error) {
	if hasDuplicate(args) {
		return nil, errors.New("Cannot defined a backend type multiple times")
	}

	for _, i := range args {
		switch i {
		default:
			err := fmt.Errorf("Invalid session_backend type '%s'", i)
			return nil, err
		case "mem", "redis", "db":
			break
		}
	}
	return args, nil
}

// Build the ApiAAAHandler which will initialize the cache and instantiate the router along with its routes
func (h *ApiAAAHandler) buildApiAAAHandler(ctx context.Context) error {
	webservices := &pfconfigdriver.PfConfWebservices{}
	unifiedApiSystemUser := &pfconfigdriver.UnifiedApiSystemUser{}
	advanced := &pfconfigdriver.PfConfAdvanced{}
	adminLogin := &pfconfigdriver.PfConfAdminLogin{}
	servicesURL := &pfconfigdriver.PfConfServicesURL{}

	pfconfigdriver.UpdateConfigStore(ctx, func(ctx context.Context, u *pfconfigdriver.ConfigStoreUpdater) {
		u.AddStruct(ctx, "PfConfWebservices", webservices)
		u.AddStruct(ctx, "UnifiedApiSystemUser", unifiedApiSystemUser)
		u.AddStruct(ctx, "PfConfAdvanced", advanced)
		u.AddStruct(ctx, "PfConfAdminLogin", adminLogin)
		u.AddStruct(ctx, "PfConfServicesURL", servicesURL)
	})

	tokenBackend := aaa.MakeTokenBackend(ctx, h.TokenBackend)
	h.authentication = aaa.NewTokenAuthenticationMiddleware(tokenBackend)

	// Backend for the system Unified API user
	if unifiedApiSystemUser.User != "" {
		h.systemBackend = aaa.NewMemAuthenticationBackend(
			map[string]string{},
			map[string]bool{"ALL": true},
		)
		h.systemBackend.SetUser(unifiedApiSystemUser.User, unifiedApiSystemUser.Pass)
		h.authentication.AddAuthenticationBackend(h.systemBackend)
	} else {
		return errors.New("Unable to setup the system user authentication backend")
	}

	// Backend for the pf.conf webservices user
	h.webservicesBackend = aaa.NewMemAuthenticationBackend(
		map[string]string{},
		map[string]bool{"ALL": true},
	)
	h.authentication.AddAuthenticationBackend(h.webservicesBackend)

	if webservices.User != "" {
		h.webservicesBackend.SetUser(webservices.User, webservices.Pass)
	}

	// Backend for SSO
	if sharedutils.IsEnabled(adminLogin.SSOStatus) {
		url, err := url.Parse(fmt.Sprintf("%s%s", adminLogin.SSOBaseUrl, adminLogin.SSOAuthorizePath))
		sharedutils.CheckError(err)
		h.authentication.AddAuthenticationBackend(aaa.NewPortalAuthenticationBackend(ctx, url, false))
	}

	// Backend for username/password auth via the internal auth sources
	if sharedutils.IsEnabled(adminLogin.AllowUsernamePassword) {
		url, err := url.Parse(fmt.Sprintf("%s/api/v1/authentication/admin_authentication", servicesURL.PfperlApi))
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
	w.Header().Set("Content-Type", "application/json")

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
			AdminActions: make([]string, len(info.AdminActions(ctx))),
			AdminRoles:   make([]string, len(info.AdminRoles)),
			Username:     info.Username,
			ExpiresAt:    expiration,
		}

		i := 0
		for r, _ := range info.AdminActions(ctx) {
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
	adminLogin := pfconfigdriver.GetStruct(r.Context(), "PfConfAdminLogin").(*pfconfigdriver.PfConfAdminLogin)
	info := struct {
		LoginText string `json:"login_text"`
		LoginURL  string `json:"login_url"`
		IsEnabled bool   `json:"is_enabled"`
	}{
		LoginText: adminLogin.SSOLoginText,
		LoginURL:  fmt.Sprintf("%s%s", adminLogin.SSOBaseUrl, adminLogin.SSOLoginPath),
		IsEnabled: sharedutils.IsEnabled(adminLogin.SSOStatus),
	}

	json.NewEncoder(w).Encode(info)
}

func (h ApiAAAHandler) HandleAAA(w http.ResponseWriter, r *http.Request) bool {
	if aaa.IsPathPublic(r.URL.Path) {
		return true
	}

	ctx := r.Context()

	// Perform HTTP Basic Auth for FleetDM event reporting
	username, password, succ := r.BasicAuth()
	if succ && username != "" && password != "" {
		auth, token, err := h.authentication.Login(ctx, username, password)
		if !auth {
			w.WriteHeader(http.StatusUnauthorized)
			res, _ := json.Marshal(map[string]string{
				"message": err.Error(),
			})
			fmt.Fprintf(w, string(res))
			return false
		}
		r.Header.Set("Authorization", "Bearer "+token)
	}

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
	webservices := pfconfigdriver.GetStruct(ctx, "PfConfWebservices").(*pfconfigdriver.PfConfWebservices)
	// Reload the webservices user info
	if webservices.User != "" {
		h.webservicesBackend.SetUser(webservices.User, webservices.Pass)
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
		}
	}
	return nil
}

func (p *ApiAAAHandler) Validate() error {
	return nil
}

func (p *ApiAAAHandler) Cleanup() error {
	return nil
}

var (
	_ caddy.Provisioner           = (*ApiAAAHandler)(nil)
	_ caddy.CleanerUpper          = (*ApiAAAHandler)(nil)
	_ caddy.Validator             = (*ApiAAAHandler)(nil)
	_ caddyhttp.MiddlewareHandler = (*ApiAAAHandler)(nil)
	_ caddyfile.Unmarshaler       = (*ApiAAAHandler)(nil)
)
