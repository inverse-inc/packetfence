package api

import (
	"context"
	"net/http"
	"sync"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"

	"github.com/inverse-inc/packetfence/go/fbcollectorclient"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2"
	"github.com/julienschmidt/httprouter"
)

var setupOnce = sync.Once{}

// Register the plugin in caddy
func init() {
	caddy.RegisterModule(APIHandler{})
	httpcaddyfile.RegisterHandlerDirective("api", caddy2.ParseCaddyfile[APIHandler])
}

type APIHandler struct {
	caddy2.ModuleBase
	router *httprouter.Router
}

func (h APIHandler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID:  "http.handlers.api",
		New: func() caddy.Module { return &APIHandler{} },
	}
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

// Build the Handler which will initialize the routes
func (h *APIHandler) Provision(ctx caddy.Context) error {
	setupOnce.Do(func() {
		setupRadiusDictionary()
		pfconfigdriver.PfconfigPool.AddRefreshable(context.Background(), fbcollectorclient.DefaultClient)
	})

	h.router = httprouter.New()
	h.router.POST("/api/v1/radius_attributes", h.searchRadiusAttributes)
	h.router.POST("/api/v1/nodes/fingerbank_communications", h.nodeFingerbankCommunications)

	NewAdminApiAuditLog().AddToRouter(h.router)
	NewAuthLog().AddToRouter(h.router)
	NewDnsAuditLog().AddToRouter(h.router)
	NewRadacctLog().AddToRouter(h.router)
	NewRadiusAuditLog().AddToRouter(h.router)
	NewWrix().AddToRouter(h.router)

	return nil
}
