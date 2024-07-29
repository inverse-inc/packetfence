package caddystatsd

import (
	"errors"
	"fmt"
	"net/http"
	"strconv"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
)

// Register the plugin
func init() {
	caddy.RegisterModule(RequestLimitHandler{})
	httpcaddyfile.RegisterHandlerDirective("requestlimit", utils.ParseCaddyfile[RequestLimitHandler])
}

// CaddyModule returns the Caddy module information.
func (RequestLimitHandler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.requestlimit",
		New: func() caddy.Module {
			return &RequestLimitHandler{}
		},
	}
}

// Setup the rate limiter with the configuration in the Caddyfile
func (s *RequestLimitHandler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	var max int

	for c.Next() {
		val := c.Val()
		switch val {
		case "requestlimit":
			if !c.NextArg() {
				fmt.Println("Missing limit argument for requestlimit")
				return c.ArgErr()
			} else {
				val := c.Val()
				if val != "" {
					max64, err := strconv.ParseInt(c.Val(), 10, 32)
					if err != nil {
						msg := fmt.Sprintf("Cannot parse request limit value %s", val)
						return errors.New(msg)
					} else {
						max = int(max64)
						fmt.Printf("Setting up requestlimit with a limit of %d\n", max)
						break
					}
				}
			}
		default:
			return c.ArgErr()
		}
	}

	s.Max = max
	return nil
}

type RequestLimitHandler struct {
	Max int      `json:"max"`
	sem chan int `json:"-"`
}

func (r *RequestLimitHandler) Cleanup() error {
	return nil
}

// Middleware that will rate limit the amount of concurrent requests the webserver can do at once
// Controlled via the sem channel which has a capacity defined by the limit that is in the Caddyfile
func (h *RequestLimitHandler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	// Limit the concurrent requests that can run through the sem channel
	h.sem <- 1
	defer func() {
		<-h.sem
	}()

	return next.ServeHTTP(w, r)
}

func (h *RequestLimitHandler) Provision(ctx caddy.Context) error {
	h.sem = make(chan int, h.Max)
	return nil
}

func (h *RequestLimitHandler) Validate() error {
	if h.Max <= 0 {
		return errors.New("RequestLimitHandler request limiter must be greater than zero")
	}

	return nil
}

var (
	_ caddy.Provisioner           = (*RequestLimitHandler)(nil)
	_ caddy.CleanerUpper          = (*RequestLimitHandler)(nil)
	_ caddy.Validator             = (*RequestLimitHandler)(nil)
	_ caddyhttp.MiddlewareHandler = (*RequestLimitHandler)(nil)
	_ caddyfile.Unmarshaler       = (*RequestLimitHandler)(nil)
)
