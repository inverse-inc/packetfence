package cors

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/captncraig/cors"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
)

func init() {
	caddy.RegisterModule(Handler{})
	httpcaddyfile.RegisterHandlerDirective("cors", utils.ParseCaddyfile[Handler])
}

type Handler struct {
	cors             *cors.Config `json:"-"`
	Path             string       `json:"path"`
	AllowedOrigins   []string     `json:"allowed_origins"`
	AllowedMethods   string       `json:"allowed_methods"`
	AllowCredentials bool         `json:"allow_credentials"`
	MaxAge           int          `json:"max_age"`
	AllowedHeaders   string       `json:"allowed_headers"`
	ExposedHeaders   string       `json:"exposed_headers"`
}

// CaddyModule returns the Caddy module information.
func (Handler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.cors",
		New: func() caddy.Module {
			return &Handler{}
		},
	}
}

func (h *Handler) Provision(_ caddy.Context) error {

	conf := cors.Default()
	h.cors = conf
	conf.AllowedMethods = h.AllowedMethods
	conf.MaxAge = h.MaxAge
	conf.AllowCredentials = &h.AllowCredentials
	conf.ExposedHeaders = h.ExposedHeaders
	conf.AllowedHeaders = h.AllowedHeaders
	conf.AllowedOrigins = h.AllowedOrigins

	return nil
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	if Path(r.URL.Path).Matches(h.Path, false) {
		h.cors.HandleRequest(w, r)
		if cors.IsPreflight(r) {
			return nil
		}
	}

	return next.ServeHTTP(w, r)
}

func (h *Handler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	c.Next()
	args := c.RemainingArgs()
	if len(args) > 0 {
		h.Path = args[0]
	}

	for i := 1; i < len(args); i++ {
		h.AllowedOrigins = append(h.AllowedOrigins, strings.Split(args[i], ",")...)
	}

	for c.NextBlock(0) {
		switch c.Val() {
		case "origin":
			for i := 1; i < len(args); i++ {
				h.AllowedOrigins = append(h.AllowedOrigins, strings.Split(args[i], ",")...)
			}
		case "methods":
			if arg, err := singleArg(c, "methods"); err != nil {
				return err
			} else {
				h.AllowedMethods = arg
			}
		case "allow_credentials":
			if arg, err := singleArg(c, "allow_credentials"); err != nil {
				return err
			} else {
				var b bool
				if arg == "true" {
					b = true
				} else if arg != "false" {
					return c.Errf("allow_credentials must be true or false.")
				}
				h.AllowCredentials = b
			}
		case "max_age":
			if arg, err := singleArg(c, "max_age"); err != nil {
				return err
			} else {
				i, err := strconv.Atoi(arg)
				if err != nil {
					return c.Err("max_age must be valid int")
				}
				h.MaxAge = i
			}
		case "allowed_headers":
			if arg, err := singleArg(c, "allowed_headers"); err != nil {
				return err
			} else {
				h.AllowedHeaders = arg
			}
		case "exposed_headers":
			if arg, err := singleArg(c, "exposed_headers"); err != nil {
				return err
			} else {
				h.ExposedHeaders = arg
			}
		default:
			return c.Errf("Unknown cors config item: %s", c.Val())
		}
	}

	return nil
}

func singleArg(c *caddyfile.Dispenser, desc string) (string, error) {
	args := c.RemainingArgs()
	if len(args) != 1 {
		return "", c.Errf("%s expects exactly one argument", desc)
	}

	return args[0], nil
}

func (p *Handler) Validate() error {
	return nil
}

func (p *Handler) Cleanup() error {
	return nil
}

var (
	_ caddy.Provisioner           = (*Handler)(nil)
	_ caddy.CleanerUpper          = (*Handler)(nil)
	_ caddy.Validator             = (*Handler)(nil)
	_ caddyhttp.MiddlewareHandler = (*Handler)(nil)
	_ caddyfile.Unmarshaler       = (*Handler)(nil)
)
