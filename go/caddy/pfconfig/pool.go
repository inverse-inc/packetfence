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

func setup(c *caddy.Controller) error {
	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		return Pool{Next: next}
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

type Pool struct {
	Next httpserver.Handler
}

func (h Pool) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	pfconfigdriver.PfconfigPool.ReadLock(r.Context())
	defer pfconfigdriver.PfconfigPool.ReadUnlock(r.Context())

	return h.Next.ServeHTTP(w, r)
}
