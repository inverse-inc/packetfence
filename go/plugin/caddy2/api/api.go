package api

import (
	"context"
	"net/http"


	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"

	"github.com/inverse-inc/packetfence/go/fbcollectorclient"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/julienschmidt/httprouter"
)

// Register the plugin in caddy
func init() {
	caddy.RegisterModule(APIHandler{})
	setupRadiusDictionary()
	pfconfigdriver.PfconfigPool.AddRefreshable(context.Background(), fbcollectorclient.DefaultClient)
	httpcaddyfile.RegisterHandlerDirective("api", parseCaddyfile)
}

type APIHandler struct {
	router *httprouter.Router
}

func (h APIHandler) CaddyModule() caddy.ModuleInfo {
    return caddy.ModuleInfo {
        ID: "http.handlers.api",
        New: func() caddy.Module { return &APIHandler{} },
    }
}

func (h *APIHandler) init(ctx context.Context) error {
	h.router = httprouter.New()

	h.router.POST("/api/v1/radius_attributes", h.searchRadiusAttributes)

	h.router.POST("/api/v1/nodes/fingerbank_communications", h.nodeFingerbankCommunications)

    return nil
}

// Build the Handler which will initialize the routes
func buildHandler(ctx context.Context) (APIHandler, error) {
	apiHandler := APIHandler{}
	router := httprouter.New()

	router.POST("/api/v1/radius_attributes", apiHandler.searchRadiusAttributes)

	router.POST("/api/v1/nodes/fingerbank_communications", apiHandler.nodeFingerbankCommunications)

	apiHandler.router = router
	return apiHandler, nil
}

func (h *APIHandler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	ctx := r.Context()
	defer panichandler.Http(ctx, w)

	if handle, params, _ := h.router.Lookup(r.Method, r.URL.Path); handle != nil {
		// We always default to application/json
		w.Header().Set("Content-Type", "application/json")
		handle(w, r, params)
		return nil
	}

	return next.ServeHTTP(w, r)

}

func (h *APIHandler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
    return nil
}

// parseCaddyfile unmarshals tokens from h into a new Middleware.
func parseCaddyfile(h httpcaddyfile.Helper) (caddyhttp.MiddlewareHandler, error) {
    m := &APIHandler{}
	err := m.UnmarshalCaddyfile(h.Dispenser)
    return m, err
}

func (h *APIHandler) Validate() error {
    return nil
}

func (h *APIHandler) Provision(ctx caddy.Context) error {
    return h.init(ctx)
}

// Interface guards
var (
	_ caddy.Provisioner           = (*APIHandler)(nil)
	_ caddy.Validator             = (*APIHandler)(nil)
	_ caddyhttp.MiddlewareHandler = (*APIHandler)(nil)
	_ caddyfile.Unmarshaler       = (*APIHandler)(nil)
)
