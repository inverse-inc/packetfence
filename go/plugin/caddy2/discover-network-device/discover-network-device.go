package discovernetworkdevice

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/inverse-inc/packetfence/go/netscan"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/pfqueueclient"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
	"github.com/inverse-inc/packetfence/go/redisclient"
	"github.com/julienschmidt/httprouter"
	"github.com/redis/go-redis/v9"
)

var rootCtx = context.Background()

type CtxCancel struct {
	Ctx    context.Context
	Cancel context.CancelFunc
}

var tasksCtxs sync.Map

// Register the plugin in caddy
func init() {
	caddy.RegisterModule(Module{})
	httpcaddyfile.RegisterHandlerDirective("discover-network-device", utils.ParseCaddyfile[Module])
}

// CaddyModule returns the Caddy module information.
func (Module) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.discover-network-device",
		New: func() caddy.Module {
			return &Module{}
		},
	}
}

type Module struct {
	router *httprouter.Router
	redis  *redis.Client
}

func (m *Module) Provision(ctx caddy.Context) error {
	pfconfigdriver.AddStruct(ctx, "redisConfig", &redisclient.PfqueueConsumerConfig{})
	redisConfig := pfconfigdriver.GetStruct(ctx, "redisConfig").(*redisclient.PfqueueConsumerConfig)
	var network string
	if redisConfig.RedisArgs.Server[0] == '/' {
		network = "unix"
	} else {
		network = "tcp"
	}
	m.redis = redis.NewClient(&redis.Options{
		Addr:    redisConfig.RedisArgs.Server,
		Network: network,
	})

	m.router = httprouter.New()
	m.router.POST("/api/v1/discovernetworkdevice/discover", m.handleDiscover)
	m.router.POST("/api/v1/discovernetworkdevice/discover/:id/cancel", m.cancelDiscover)
	return nil
}

func ScanTask(ctx context.Context, payload netscan.ScanRequest,
	progressCb func(int, string)) (*netscan.ScanResponse, error) {
	resp, err := netscan.SnmpScan(ctx, payload, netscan.WithProgress(progressCb))
	if err != nil {
		return nil, err
	}
	return resp, nil
}

func (m *Module) handleDiscover(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	b := bytes.NewBuffer(nil)
	b.ReadFrom(r.Body)
	body := netscan.ScanRequest{}
	if err := json.Unmarshal(b.Bytes(), &body); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	task := pfqueueclient.NewApiTask()
	ctx, cancel := context.WithCancel(rootCtx)
	tasksCtxs.Store(task.TaskId, &CtxCancel{ctx, cancel})
	go func() {
		statusUpdater := pfqueueclient.NewStatusUpdater(task.TaskId, time.Hour, m.redis)
		defer func() {
			tasksCtxs.Delete(task.TaskId)
			if r := recover(); r != nil {
				statusUpdater.Failed(rootCtx, r)
			}
			pfqueueclient.PutStatusUpdater(statusUpdater)
		}()
		defer cancel()
		statusUpdater.Start(ctx)
		data, err := ScanTask(ctx, body, func(progress int, message string) {
			statusUpdater.UpdateProgress(ctx, progress, message)
		})
		if ctx.Err() != nil {
			statusUpdater.Failed(rootCtx, "Task cancelled")
		} else if err != nil {
			statusUpdater.Failed(rootCtx, err.Error())
		} else {
			statusUpdater.Complete(rootCtx, data)
		}
	}()
	res, _ := json.Marshal(&task)
	w.WriteHeader(task.Status)
	w.Write(res)
}

func (m *Module) cancelDiscover(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	taskId := p.ByName("id")
	if len(taskId) == 0 {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	_ctx, ok := tasksCtxs.LoadAndDelete(taskId)
	if !ok {
		w.WriteHeader(http.StatusNotFound)
		return
	}
	ctx := _ctx.(*CtxCancel)
	ctx.Cancel()
	w.WriteHeader(http.StatusOK)
}

func (m *Module) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	ctx := r.Context()

	defer panichandler.Http(ctx, w)

	if handle, params, _ := m.router.Lookup(r.Method, r.URL.Path); handle != nil {
		// We always default to application/json
		w.Header().Set("Content-Type", "application/json")

		handle(w, r, params)
		return nil
	}

	return next.ServeHTTP(w, r)
}

func (m *Module) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	c.Next()
	return nil
}

func (m *Module) Cleanup() error {
	return nil
}

func (m *Module) Validate() error {
	return nil
}

var (
	_ caddy.Provisioner           = (*Module)(nil)
	_ caddy.CleanerUpper          = (*Module)(nil)
	_ caddy.Validator             = (*Module)(nil)
	_ caddyhttp.MiddlewareHandler = (*Module)(nil)
	_ caddyfile.Unmarshaler       = (*Module)(nil)
)
