package caddystatsd

import (
	"errors"
	"fmt"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"net/http"
	"strconv"
)

// Register the plugin
func init() {
	caddy.RegisterPlugin("requestlimit", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

// Setup the rate limiter with the configuration in the Caddyfile
func setup(c *caddy.Controller) error {
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

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		return RequestLimitHandler{Next: next, sem: make(chan int, max)}
	})

	return nil
}

type RequestLimitHandler struct {
	Next httpserver.Handler
	sem  chan int
}

// Middleware that will rate limit the amount of concurrent requests the webserver can do at once
// Controlled via the sem channel which has a capacity defined by the limit that is in the Caddyfile
func (h RequestLimitHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	// Limit the concurrent requests that can run through the sem channel
	h.sem <- 1
	defer func() {
		<-h.sem
	}()

	return h.Next.ServeHTTP(w, r)
}
