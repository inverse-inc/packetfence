package apiaaa

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"time"

	"github.com/inverse-inc/packetfence/go/api-frontend/aaa"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/inverse-inc/packetfence/go/statsd"
	"github.com/julienschmidt/httprouter"
)

// Register the plugin in caddy
func init() {
	caddy.RegisterPlugin("api-aaa", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

type PrettyTokenInfo struct {
	AdminActions []string  `json:"admin_actions"`
	AdminRoles   []string  `json:"admin_roles"`
	TenantId     int       `json:"tenant_id"`
	Username     string    `json:"username"`
	ExpiresAt    time.Time `json:"expires_at"`
}

type ApiAAAHandler struct {
	Next               httpserver.Handler
	router             *httprouter.Router
	systemBackend      *aaa.MemAuthenticationBackend
	webservicesBackend *aaa.MemAuthenticationBackend
	authentication     *aaa.TokenAuthenticationMiddleware
	authorization      *aaa.TokenAuthorizationMiddleware
}

// Setup the api-aaa middleware
// Also loads the pfconfig resources and registers them in the pool
func setup(c *caddy.Controller) error {
	ctx := log.LoggerNewContext(context.Background())

	apiAAA, err := buildApiAAAHandler(ctx)

	if err != nil {
		return err
	}

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		apiAAA.Next = next
		return apiAAA
	})

	return nil
}

// Build the ApiAAAHandler which will initialize the cache and instantiate the router along with its routes
func buildApiAAAHandler(ctx context.Context) (ApiAAAHandler, error) {

	apiAAA := ApiAAAHandler{}

	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Webservices)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.UnifiedApiSystemUser)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.AdminRoles)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Advanced)

	tokenBackend := aaa.NewMemTokenBackend(
		time.Duration(pfconfigdriver.Config.PfConf.Advanced.ApiInactivityTimeout)*time.Second,
		time.Duration(pfconfigdriver.Config.PfConf.Advanced.ApiMaxExpiration)*time.Second,
	)
	apiAAA.authentication = aaa.NewTokenAuthenticationMiddleware(tokenBackend)

	// Backend for the system Unified API user
	if pfconfigdriver.Config.UnifiedApiSystemUser.User != "" {
		apiAAA.systemBackend = aaa.NewMemAuthenticationBackend(
			map[string]string{},
			map[string]bool{"ALL": true},
		)
		apiAAA.systemBackend.SetUser(pfconfigdriver.Config.UnifiedApiSystemUser.User, pfconfigdriver.Config.UnifiedApiSystemUser.Pass)
		apiAAA.authentication.AddAuthenticationBackend(apiAAA.systemBackend)
	}

	// Backend for the pf.conf webservices user
	apiAAA.webservicesBackend = aaa.NewMemAuthenticationBackend(
		map[string]string{},
		map[string]bool{"ALL": true},
	)
	apiAAA.authentication.AddAuthenticationBackend(apiAAA.webservicesBackend)

	if pfconfigdriver.Config.PfConf.Webservices.User != "" {
		apiAAA.webservicesBackend.SetUser(pfconfigdriver.Config.PfConf.Webservices.User, pfconfigdriver.Config.PfConf.Webservices.Pass)
	}

	url, err := url.Parse("http://127.0.0.1:22224/api/v1/authentication/admin_authentication")
	sharedutils.CheckError(err)
	apiAAA.authentication.AddAuthenticationBackend(aaa.NewPfAuthenticationBackend(ctx, url, false))

	apiAAA.authorization = aaa.NewTokenAuthorizationMiddleware(tokenBackend)

	router := httprouter.New()
	router.POST("/api/v1/login", apiAAA.handleLogin)
	router.GET("/api/v1/token_info", apiAAA.handleTokenInfo)

	apiAAA.router = router

	return apiAAA, nil
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
			TenantId:     info.TenantId,
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
		w.WriteHeader(http.StatusForbidden)
		res, _ := json.Marshal(map[string]string{
			"message": err.Error(),
		})
		fmt.Fprintf(w, string(res))
		return false
	}
}

func (h ApiAAAHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()

	// Reload the webservices user info
	if pfconfigdriver.Config.PfConf.Webservices.User != "" {
		h.webservicesBackend.SetUser(pfconfigdriver.Config.PfConf.Webservices.User, pfconfigdriver.Config.PfConf.Webservices.Pass)
	}

	defer panichandler.Http(ctx, w)

	// We always default to application/json
	w.Header().Set("Content-Type", "application/json")

	if handle, params, _ := h.router.Lookup(r.Method, r.URL.Path); handle != nil {
		handle(w, r, params)

		// TODO change me and wrap actions into something that handles server errors
		return 0, nil
	} else {
		if h.HandleAAA(w, r) {
			return h.Next.ServeHTTP(w, r)
		} else {
			// TODO change me and wrap actions into something that handles server errors
			return 0, nil
		}
	}

}
