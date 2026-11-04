package adminuiplugins

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
)

// PathPrefix is the API path under which the admin UI plugins are proxied: /api/v1/plugins/<id>/...
const PathPrefix = "/api/v1/plugins/"

func init() {
	caddy.RegisterModule(AdminUiPlugins{})
	httpcaddyfile.RegisterHandlerDirective("admin-ui-plugins", utils.ParseCaddyfile[AdminUiPlugins])
}

// AdminUiPlugins proxies /api/v1/plugins/<id>/* to the upstream of the plugin defined in admin_ui_plugins.conf
type AdminUiPlugins struct {
	lookup  func(ctx context.Context, id string) (pfconfigdriver.AdminUiPlugin, bool)
	proxies *sync.Map
}

// CaddyModule returns the Caddy module information.
func (AdminUiPlugins) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.admin-ui-plugins",
		New: func() caddy.Module {
			return &AdminUiPlugins{proxies: &sync.Map{}}
		},
	}
}

func (h *AdminUiPlugins) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	c.Next()
	return nil
}

func (h *AdminUiPlugins) Provision(ctx caddy.Context) error {
	if h.lookup == nil {
		h.lookup = lookupPfconfig
	}

	if h.proxies == nil {
		h.proxies = &sync.Map{}
	}

	return nil
}

func (h *AdminUiPlugins) Validate() error {
	return nil
}

func lookupPfconfig(ctx context.Context, id string) (pfconfigdriver.AdminUiPlugin, bool) {
	plugins := pfconfigdriver.GetType[pfconfigdriver.AdminUiPlugins](ctx)
	if plugins == nil {
		return pfconfigdriver.AdminUiPlugin{}, false
	}

	plugin, found := plugins.Element[id]
	return plugin, found
}

func (h *AdminUiPlugins) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	if !strings.HasPrefix(r.URL.Path, PathPrefix) {
		return next.ServeHTTP(w, r)
	}

	ctx := r.Context()
	id, rest, _ := strings.Cut(strings.TrimPrefix(r.URL.Path, PathPrefix), "/")
	plugin, found := h.lookup(ctx, id)
	if !found || !sharedutils.IsEnabled(plugin.Enabled) {
		writeError(w, http.StatusNotFound, fmt.Sprintf("Unknown admin UI plugin %s", id))
		return nil
	}

	proxy, err := h.proxy(plugin.Upstream)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Invalid upstream for the admin UI plugin %s: %s", id, err))
		writeError(w, http.StatusBadGateway, fmt.Sprintf("Invalid upstream for the admin UI plugin %s", id))
		return nil
	}

	r2 := r.Clone(ctx)
	r2.URL.Path = "/" + rest
	r2.URL.RawPath = ""
	proxy.ServeHTTP(w, r2)
	return nil
}

func (h *AdminUiPlugins) proxy(upstream string) (*httputil.ReverseProxy, error) {
	if p, found := h.proxies.Load(upstream); found {
		return p.(*httputil.ReverseProxy), nil
	}

	target, err := url.Parse(upstream)
	if err != nil {
		return nil, err
	}

	if (target.Scheme != "http" && target.Scheme != "https") || target.Host == "" {
		return nil, fmt.Errorf("%s is not an http or https URL", upstream)
	}

	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.ResponseHeaderTimeout = 60 * time.Second

	p := &httputil.ReverseProxy{
		Rewrite: func(pr *httputil.ProxyRequest) {
			pr.SetURL(target)
			pr.SetXForwarded()
		},
		Transport: transport,
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			log.LoggerWContext(r.Context()).Error(fmt.Sprintf("Error while proxying to the admin UI plugin %s: %s", upstream, err))
			writeError(w, http.StatusBadGateway, "The admin UI plugin is unavailable")
		},
	}

	actual, _ := h.proxies.LoadOrStore(upstream, p)
	return actual.(*httputil.ReverseProxy), nil
}

func writeError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": message,
		"status":  status,
	})
}

var (
	_ caddy.Provisioner           = (*AdminUiPlugins)(nil)
	_ caddy.Validator             = (*AdminUiPlugins)(nil)
	_ caddyhttp.MiddlewareHandler = (*AdminUiPlugins)(nil)
	_ caddyfile.Unmarshaler       = (*AdminUiPlugins)(nil)
)
