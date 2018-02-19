package caddy

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/captncraig/cors"

	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
)

type corsRule struct {
	Conf *cors.Config
	Path string
}

func init() {
	caddy.RegisterPlugin("cors", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

func setup(c *caddy.Controller) error {
	rules, err := parseRules(c)
	if err != nil {
		return err
	}
	siteConfig := httpserver.GetConfig(c)
	siteConfig.AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		return httpserver.HandlerFunc(func(w http.ResponseWriter, r *http.Request) (int, error) {
			for _, rule := range rules {
				if httpserver.Path(r.URL.Path).Matches(rule.Path) {
					rule.Conf.HandleRequest(w, r)
					if cors.IsPreflight(r) {
						return 200, nil
					}
					break
				}
			}
			return next.ServeHTTP(w, r)
		})
	})
	return nil
}

func parseRules(c *caddy.Controller) ([]*corsRule, error) {
	rules := []*corsRule{}

	for c.Next() {
		rule := &corsRule{Path: "/", Conf: cors.Default()}
		args := c.RemainingArgs()

		anyOrigins := false
		if len(args) > 0 {
			rule.Path = args[0]
		}
		for i := 1; i < len(args); i++ {
			if !anyOrigins {
				rule.Conf.AllowedOrigins = nil
			}
			rule.Conf.AllowedOrigins = append(rule.Conf.AllowedOrigins, strings.Split(args[i], ",")...)
			anyOrigins = true
		}
		for c.NextBlock() {
			switch c.Val() {
			case "origin":
				if !anyOrigins {
					rule.Conf.AllowedOrigins = nil
				}
				args := c.RemainingArgs()
				for _, domain := range args {
					rule.Conf.AllowedOrigins = append(rule.Conf.AllowedOrigins, strings.Split(domain, ",")...)
				}
				anyOrigins = true
			case "methods":
				if arg, err := singleArg(c, "methods"); err != nil {
					return nil, err
				} else {
					rule.Conf.AllowedMethods = arg
				}
			case "allow_credentials":
				if arg, err := singleArg(c, "allow_credentials"); err != nil {
					return nil, err
				} else {
					var b bool
					if arg == "true" {
						b = true
					} else if arg != "false" {
						return nil, c.Errf("allow_credentials must be true or false.")
					}
					rule.Conf.AllowCredentials = &b
				}
			case "max_age":
				if arg, err := singleArg(c, "max_age"); err != nil {
					return nil, err
				} else {
					i, err := strconv.Atoi(arg)
					if err != nil {
						return nil, c.Err("max_age must be valid int")
					}
					rule.Conf.MaxAge = i
				}
			case "allowed_headers":
				if arg, err := singleArg(c, "allowed_headers"); err != nil {
					return nil, err
				} else {
					rule.Conf.AllowedHeaders = arg
				}
			case "exposed_headers":
				if arg, err := singleArg(c, "exposed_headers"); err != nil {
					return nil, err
				} else {
					rule.Conf.ExposedHeaders = arg
				}
			default:
				return nil, c.Errf("Unknown cors config item: %s", c.Val())
			}
		}
		rules = append(rules, rule)
	}
	return rules, nil
}

func singleArg(c *caddy.Controller, desc string) (string, error) {
	args := c.RemainingArgs()
	if len(args) != 1 {
		return "", c.Errf("%s expects exactly one argument", desc)
	}
	return args[0], nil
}
