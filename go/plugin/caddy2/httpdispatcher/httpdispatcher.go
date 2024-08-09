package caddyhttpdispatcher

import (
	"context"
	"net/http"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/inverse-inc/packetfence/go/httpdispatcher"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
)

func init() {
	caddy.RegisterModule(HttpDispatcherHandler{})
	httpcaddyfile.RegisterHandlerDirective("httpdispatcher", utils.ParseCaddyfile[HttpDispatcherHandler])
}

// CaddyModule returns the Caddy module information.
func (HttpDispatcherHandler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.httpdispatcher",
		New: func() caddy.Module {
			return &HttpDispatcherHandler{}
		},
	}
}

func (h *HttpDispatcherHandler) Provision(_ caddy.Context) error {
	ctx := context.Background()

	pfconfigdriver.AddType[pfconfigdriver.PfConfFencing](ctx)
	pfconfigdriver.AddType[pfconfigdriver.PfConfGeneral](ctx)
	pfconfigdriver.AddType[pfconfigdriver.PfConfCaptivePortal](ctx)
	pfconfigdriver.AddType[pfconfigdriver.PfConfParking](ctx)
	proxy := httpdispatcher.NewProxy(ctx)
	h.proxy = proxy

	return nil
}

type HttpDispatcherHandler struct {
	proxy *httpdispatcher.Proxy
}

func (h *HttpDispatcherHandler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	ctx := r.Context()

	defer panichandler.Http(ctx, w)

	// This will never call the next middleware so make sure its the only «acting» middleware on this service
	h.proxy.ServeHTTP(w, r)

	// TODO change me and wrap actions into something that handles server errors
	return nil
}

func (p *HttpDispatcherHandler) Validate() error {
	return nil
}

func (p *HttpDispatcherHandler) Cleanup() error {
	return nil
}

func (s *HttpDispatcherHandler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	c.Next()
	return nil
}

var (
	_ caddy.Provisioner           = (*HttpDispatcherHandler)(nil)
	_ caddy.CleanerUpper          = (*HttpDispatcherHandler)(nil)
	_ caddy.Validator             = (*HttpDispatcherHandler)(nil)
	_ caddyhttp.MiddlewareHandler = (*HttpDispatcherHandler)(nil)
	_ caddyfile.Unmarshaler       = (*HttpDispatcherHandler)(nil)
)
