package caddy

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/captncraig/cors"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2"
)

type Cors struct {
	caddy2.ModuleBase
	rules            []corsRule
	Path             string   `json:"path"`
	Origins          []string `json:"origins"`
	Methods          []string `json:"methods"`
	MaxAge           int      `json:"max_age"`
	AllowCredentials bool     `json:"allow_credentials"`
	AllowedHeaders   string   `json:"allowed_headers"`
	ExposedHeaders   string   `json:"exposed_headers"`
}

type corsRule struct {
	conf *cors.Config
	Path string
}

func init() {
	caddy.RegisterModule(Cors{})
	httpcaddyfile.RegisterHandlerDirective("cors", caddy2.ParseCaddyfile[Cors])
}

func (h Cors) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID:  "http.handlers.cors",
		New: func() caddy.Module { return &Cors{} },
	}
}

func (h *Cors) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	for _, rule := range h.rules {
		rule.conf.HandleRequest(w, r)
		if cors.IsPreflight(r) {
			return nil
		}
		break
	}

	return next.ServeHTTP(w, r)
}

func (h *Cors) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {

	for c.Next() {
		h.Path = "/"
		args := c.RemainingArgs()
		for i := 0; i < len(args); i++ {
			h.Origins = append(h.Origins, strings.Split(args[i], ",")...)
		}
		for nesting := c.Nesting(); c.NextBlock(nesting); {
			switch c.Val() {
			case "origin":
				args := c.RemainingArgs()
				for _, domain := range args {
					h.Origins = append(h.Origins, strings.Split(domain, ",")...)
				}
			case "methods":
				args := c.RemainingArgs()
				for _, m := range args {
					h.Methods = append(h.Methods, strings.Split(m, ",")...)
				}
			case "allow_credentials":
				if arg, err := singleArg(c, "allow_credentials"); err != nil {
					return err
				} else {
					var b bool
					if arg == "true" {
						b = true
					} else if arg != "false" {
						return err
					}
					h.AllowCredentials = b
				}
			case "max_age":
				if arg, err := singleArg(c, "max_age"); err != nil {
					return err
				} else {
					i, err := strconv.Atoi(arg)
					if err != nil {
						return err
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
	}

	return nil
}

func (h *Cors) Provision(ctx caddy.Context) error {
	rule := corsRule{Path: "/", conf: cors.Default()}
	rule.conf.AllowedOrigins = h.Origins
	rule.conf.AllowedMethods = strings.Join(h.Methods, ",")
	rule.conf.AllowCredentials = &h.AllowCredentials
	rule.conf.MaxAge = h.MaxAge
	rule.conf.AllowedHeaders = h.AllowedHeaders
	rule.conf.ExposedHeaders = h.ExposedHeaders
	h.rules = append(h.rules, rule)
	return nil
}

func singleArg(c *caddyfile.Dispenser, desc string) (string, error) {
	args := c.RemainingArgs()
	if len(args) != 1 {
		return "", c.Errf("%s expects exactly one argument", desc)
	}
	return args[0], nil
}
