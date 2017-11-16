package apiaaa

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/inverse-inc/packetfence/go/api-frontend/aaa"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
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

type ApiAAAHandler struct {
	Next           httpserver.Handler
	router         *httprouter.Router
	authentication *aaa.TokenAuthenticationMiddleware
	authorization  *aaa.TokenAuthorizationMiddleware
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
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.AdminRoles)

	router := httprouter.New()
	router.POST("/api/v1/login", apiAAA.handleLogin)

	apiAAA.router = router

	tokenBackend := aaa.NewMemTokenBackend(1 * time.Hour)
	apiAAA.authentication = aaa.NewTokenAuthenticationMiddleware(tokenBackend)

	// Backend for the pf.conf webservices user
	if pfconfigdriver.Config.PfConf.Webservices.User != "" {
		apiAAA.authentication.AddAuthenticationBackend(aaa.NewMemAuthenticationBackend(
			map[string]string{
				pfconfigdriver.Config.PfConf.Webservices.User: pfconfigdriver.Config.PfConf.Webservices.Pass,
			},
			pfconfigdriver.Config.AdminRoles.Element["ALL"].Actions,
		))
	}

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
		res, _ := json.Marshal(struct {
			token string
		}{token: token})
		fmt.Fprintf(w, string(res))
	} else {
		w.WriteHeader(http.StatusUnauthorized)
		res, _ := json.Marshal(struct {
			message string
		}{message: err.Error()})
		fmt.Fprintf(w, string(res))
	}
}

func (h ApiAAAHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()

	defer panichandler.Http(ctx, w)

	if handle, params, _ := h.router.Lookup(r.Method, r.URL.Path); handle != nil {
		handle(w, r, params)

		// TODO change me and wrap actions into something that handles server errors
		return 0, nil
	} else {
		return h.Next.ServeHTTP(w, r)
	}

}
