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

	"github.com/inverse-inc/packetfence/go/plugin/caddy2"
)

// Register the plugin
func init() {
	caddy.RegisterModule(RequestLimitHandler{})
	httpcaddyfile.RegisterHandlerDirective("requestlimit", caddy2.ParseCaddyfile[RequestLimitHandler])
}

// Setup the rate limiter with the configuration in the Caddyfile
func (h *RequestLimitHandler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {

	for c.Next() {
		val := c.Val()
		switch val {
		case "requestlimit":
			if !c.NextArg() {
				fmt.Println("Missing limit argument for requestlimit")
				return c.ArgErr()
			}
			val := c.Val()
			if val != "" {
				max64, err := strconv.ParseInt(c.Val(), 10, 32)
				if err != nil {
					msg := fmt.Sprintf("Cannot parse request limit value %s", val)
					return errors.New(msg)
				}

				h.Max = int(max64)
				fmt.Printf("Setting up requestlimit with a limit of %d\n", h.Max)
			}
		default:
			return c.ArgErr()
		}
	}

	return nil
}

func (h *RequestLimitHandler) Provision(ctx caddy.Context) error {
	h.sem = make(chan struct{}, h.Max)
	return nil
}

type RequestLimitHandler struct {
	caddy2.ModuleBase
	Max int `json:"max"`
	sem chan struct{}
}

func (h RequestLimitHandler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID:  "http.handlers.requestlimit",
		New: func() caddy.Module { return &RequestLimitHandler{} },
	}
}

// Middleware that will rate limit the amount of concurrent requests the webserver can do at once
// Controlled via the sem channel which has a capacity defined by the limit that is in the Caddyfile
func (h *RequestLimitHandler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	// Limit the concurrent requests that can run through the sem channel
	h.sem <- struct{}{}
	defer func() {
		<-h.sem
	}()

	return next.ServeHTTP(w, r)
}
