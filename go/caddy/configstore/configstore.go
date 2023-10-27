package configstore

import (
	"net/http"

	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func init() {
	caddy.RegisterPlugin("configstore", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

func setup(c *caddy.Controller) error {

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		return ConfigStore{Next: next}
	})

	return nil
}

type ConfigStore struct {
	Next httpserver.Handler
}

func (h ConfigStore) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := pfconfigdriver.NewContext(r.Context())
	r = r.WithContext(ctx)

	return h.Next.ServeHTTP(w, r)
}
