package caddypfconfig

import (
	"context"
	"github.com/fingerbank/processor/log"
	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"net/http"
	"time"
)

func init() {
	caddy.RegisterPlugin("pfconfigpool", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

// Setup an async goroutine that refreshes the pfconfig pool every second
func setup(c *caddy.Controller) error {
	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		return PoolHandler{Next: next}
	})

	ctx := log.LoggerNewContext(context.Background())
	go func() {
		for {
			pfconfigdriver.PfconfigPool.Refresh(ctx)
			time.Sleep(1 * time.Second)
		}
	}()

	return nil
}

type PoolHandler struct {
	Next httpserver.Handler
}

// Middleware that ensures there is a read-lock on the pool during every request and released when the request is done
func (h PoolHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	pfconfigdriver.PfconfigPool.ReadLock(r.Context())
	defer pfconfigdriver.PfconfigPool.ReadUnlock(r.Context())

	return h.Next.ServeHTTP(w, r)
}
