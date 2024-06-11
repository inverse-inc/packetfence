package configstore

import (
	"context"
	"net/http"
	"sync"
	"time"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
)

func init() {
	caddy.RegisterModule(ConfigStore{})
	httpcaddyfile.RegisterHandlerDirective("configstore", utils.ParseCaddyfile[ConfigStore])
}

// CaddyModule returns the Caddy module information.
func (ConfigStore) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.configstore",
		New: func() caddy.Module {
			return &ConfigStore{}
		},
	}
}

var refreshOnceRunner sync.Once

func (s *ConfigStore) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	c.Next()
	return nil
}

type ConfigStore struct {
}

func (c *ConfigStore) Validate() error {
	return nil
}

func (c *ConfigStore) Provision(ctx caddy.Context) error {
	refreshOnceRunner.Do(func() {
		go func() {
			for {
				pfconfigdriver.PfConfigStorePool.Refresh(context.Background())
				time.Sleep(time.Second * 1)
			}
		}()
	})

	return nil
}

func (c *ConfigStore) Cleanup() error {
	return nil
}

func (h *ConfigStore) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	ctx := pfconfigdriver.NewContext(r.Context())
	r = r.WithContext(ctx)

	return next.ServeHTTP(w, r)
}

var (
	_ caddy.Provisioner           = (*ConfigStore)(nil)
	_ caddy.CleanerUpper          = (*ConfigStore)(nil)
	_ caddy.Validator             = (*ConfigStore)(nil)
	_ caddyhttp.MiddlewareHandler = (*ConfigStore)(nil)
	_ caddyfile.Unmarshaler       = (*ConfigStore)(nil)
)
