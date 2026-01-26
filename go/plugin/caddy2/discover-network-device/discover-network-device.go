package discovernetworkdevice

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/pfqueueclient"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
	"github.com/inverse-inc/packetfence/go/redisclient"
	"github.com/julienschmidt/httprouter"
	"github.com/redis/go-redis/v9"
)

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
	return nil
}

type Task struct {
	TaskId string `json:"task_id"`
	Status int    `json:"status"`
}

func ScanTask(payload Payload, progressCb func(int)) (*ScanResponse, error) {
	resp, err := SnmpScan(payload, progressCb)
	if err != nil {
		return nil, err
	}
	return resp, nil
}

func (m *Module) handleDiscover(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	b := bytes.NewBuffer(nil)
	b.ReadFrom(r.Body)
	body := Payload{}
	json.Unmarshal(b.Bytes(), &body)
	taskid := pfqueueclient.NewApiTaskID()
	task := Task{TaskId: taskid, Status: 202}
	go func(taskid string) {
		ctx := context.Background()
		statusUpdater := pfqueueclient.NewStatusUpdater(taskid, time.Hour, m.redis)
		defer func() {
			if r := recover(); r != nil {
				statusUpdater.Failed(ctx, r)
			}
			pfqueueclient.PutStatusUpdater(statusUpdater)
		}()
		statusUpdater.Start(ctx)
		data, err := ScanTask(body, func(progress int) {
			statusUpdater.UpdateProgress(ctx, progress, "Scanning...")
		})
		if err != nil {
			statusUpdater.Failed(ctx, err.Error())
		} else {
			statusUpdater.Complete(ctx, data)
		}
	}(taskid)

	res, _ := json.Marshal(&task)
	w.WriteHeader(http.StatusAccepted)
	w.Write(res)
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
