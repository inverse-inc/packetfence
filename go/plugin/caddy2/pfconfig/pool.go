package caddypfconfig

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
)

func init() {
	caddy.RegisterModule(PoolHandler{})
	httpcaddyfile.RegisterHandlerDirective("pfconfigpool", utils.ParseCaddyfile[PoolHandler])
}

// CaddyModule returns the Caddy module information.
func (PoolHandler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.pfconfigpool",
		New: func() caddy.Module {
			return &PoolHandler{}
		},
	}
}

// Setup an async goroutine that refreshes the pfconfig pool every second
func (s *PoolHandler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	noRlockPaths := []string{}
	for c.Next() {
		for c.NextBlock(0) {
			switch c.Val() {
			case "dont_rlock":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				} else {
					path := args[0]
					noRlockPaths = append(noRlockPaths, path)
					fmt.Println("Ignoring the following path for pfconfigpool rlock" + path)
				}
			default:
				return c.ArgErr()
			}
		}
	}

	s.NoRlockPaths = noRlockPaths
	return nil
}

func (m *PoolHandler) Provision(_ caddy.Context) error {
	m.refreshLauncher = &sync.Once{}
	return nil
}

type PoolHandler struct {
	refreshLauncher *sync.Once `json:"-"`
	NoRlockPaths    []string   `json:"no_rlock_paths"`
}

func (p *PoolHandler) Validate() error {
	return nil
}

func (p *PoolHandler) Cleanup() error {
	return nil
}

// Middleware that ensures there is a read-lock on the pool during every request and released when the request is done
func (h *PoolHandler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	defer panichandler.Http(r.Context(), w)

	for _, noRlock := range h.NoRlockPaths {
		if strings.HasSuffix(r.URL.Path, noRlock) {
			return next.ServeHTTP(w, r)
		}
	}

	id, err := pfconfigdriver.PfconfigPool.ReadLock(r.Context())
	if err == nil {
		defer pfconfigdriver.PfconfigPool.ReadUnlock(r.Context(), id)
		pfconfigdriver.RefreshLastTouchCache(r.Context())

		// We launch the refresh job once, the first time a request comes in
		// This ensures that the pool will run with a context that represents a request (log level for instance)
		h.refreshLauncher.Do(func() {
			ctx := r.Context()
			go func(ctx context.Context) {
				for {
					pfconfigdriver.PfconfigPool.Refresh(ctx)
					time.Sleep(1 * time.Second)
				}
			}(ctx)
		})

		return next.ServeHTTP(w, r)
	}

	panic("Unable to obtain pfconfigpool lock in caddy middleware")
}

var (
	_ caddy.Provisioner           = (*PoolHandler)(nil)
	_ caddy.CleanerUpper          = (*PoolHandler)(nil)
	_ caddy.Validator             = (*PoolHandler)(nil)
	_ caddyhttp.MiddlewareHandler = (*PoolHandler)(nil)
	_ caddyfile.Unmarshaler       = (*PoolHandler)(nil)
)
