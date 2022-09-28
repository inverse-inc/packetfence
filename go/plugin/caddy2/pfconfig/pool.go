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
	"github.com/inverse-inc/packetfence/go/plugin/caddy2"
)

func init() {
	caddy.RegisterModule(PoolHandler{})
	httpcaddyfile.RegisterHandlerDirective("pfconfigpool", caddy2.ParseCaddyfile[PoolHandler])
}

func (h PoolHandler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID:  "http.handlers.pfconfigpool",
		New: func() caddy.Module { return &PoolHandler{} },
	}
}

func (h *PoolHandler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	noRlockPaths := []string{}
	for c.Next() {
		for nesting := c.Nesting(); c.NextBlock(nesting); {
			switch c.Val() {
			case "dont_rlock":
				args := c.RemainingArgs()

				if len(args) != 1 {
					return c.ArgErr()
				}
				path := args[0]
				noRlockPaths = append(noRlockPaths, path)
				fmt.Println("Ignoring the following path for pfconfigpool rlock" + path)
			default:
				return c.ArgErr()
			}
		}
	}

	h.NoRlockPaths = noRlockPaths
	return nil
}

func (h *PoolHandler) Provision(ctx caddy.Context) error {
	h.refreshLauncher = &sync.Once{}
	return nil
}

type PoolHandler struct {
	caddy2.ModuleBase
	refreshLauncher *sync.Once `json:"-"`
	NoRlockPaths    []string   `json:"no_rlock_paths"`
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
	} else {
		panic("Unable to obtain pfconfigpool lock in caddy middleware")
	}
}
