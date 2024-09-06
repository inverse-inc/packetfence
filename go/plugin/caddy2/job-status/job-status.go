package jobstatus

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/redis/go-redis/v9"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/utils"
	"github.com/inverse-inc/packetfence/go/redisclient"
	"github.com/julienschmidt/httprouter"
)

const STATUS_PENDING = 202
const STATUS_COMPLETED = 200
const STATUS_FAILED = 400

const STATUS_COMPLETED_STR = "200"
const STATUS_PENDING_STR = "202"
const STATUS_FAILED_STR = "400"

const POLL_TIMEOUT = 30

// Register the plugin in caddy
func init() {
	caddy.RegisterModule(JobStatusHandler{})
	httpcaddyfile.RegisterHandlerDirective("job-status", utils.ParseCaddyfile[JobStatusHandler])
}

// CaddyModule returns the Caddy module information.
func (JobStatusHandler) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID: "http.handlers.job-status",
		New: func() caddy.Module {
			return &JobStatusHandler{}
		},
	}
}

type JobStatusHandler struct {
	router *httprouter.Router
	redis  *redis.Client
}

func (j *JobStatusHandler) Cleanup() error {
	return nil
}

func (j *JobStatusHandler) Validate() error {
	return nil
}

// Setup the api-aaa middleware
// Also loads the pfconfig resources and registers them in the pool
func (h *JobStatusHandler) Provision(_ caddy.Context) error {
	ctx := log.LoggerNewContext(context.Background())

	err := h.buildJobStatusHandler(ctx)

	if err != nil {
		return err
	}

	return nil
}

// Build the JobStatusHandler which will initialize the cache and instantiate the router along with its routes
func (h *JobStatusHandler) buildJobStatusHandler(ctx context.Context) error {

	pfconfigdriver.AddStruct(ctx, "redisConfig", &redisclient.PfqueueConsumerConfig{})
	redisConfig := pfconfigdriver.GetStruct(ctx, "redisConfig").(*redisclient.PfqueueConsumerConfig)
	var network string
	if redisConfig.RedisArgs.Server[0] == '/' {
		network = "unix"
	} else {
		network = "tcp"
	}

	h.redis = redis.NewClient(&redis.Options{
		Addr:    redisConfig.RedisArgs.Server,
		Network: network,
	})

	router := httprouter.New()
	router.GET("/api/v1/pfqueue/task/:job_id/status", h.handleStatus)
	router.GET("/api/v1/pfqueue/task/:job_id/status/poll", h.handleStatusPoll)

	h.router = router

	return nil
}

func (h *JobStatusHandler) sendResults(w http.ResponseWriter, data map[string]string) {
	results := map[string]interface{}{}
	for k, v := range data {
		switch k {
		case "item", "error":
			results[k] = json.RawMessage(v)
		case "status":
			if i, err := strconv.Atoi(v); err != nil {
				results[k] = 400
			} else {
				results[k] = i
			}
		default:
			results[k] = v
		}
	}

	res, _ := json.Marshal(results)
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, string(res))
}

func (h *JobStatusHandler) handleStatusPoll(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()
	jobId := p.ByName("job_id")

	data, err := h.redis.HGetAll(ctx, h.jobStatusKey(jobId)).Result()
	if err != nil {
		msg := "Unable to get job status from redis database"
		h.writeMessage(ctx, http.StatusInternalServerError, msg, w)
		log.LoggerWContext(ctx).Error(msg + ": " + err.Error())
		return
	} else if status := data["status"]; status == STATUS_COMPLETED_STR || status == STATUS_FAILED_STR {
		h.sendResults(w, data)
		return
	}

	updatesKey := h.jobStatusUpdatesKey(jobId)

	_, err = h.redis.BRPop(ctx, POLL_TIMEOUT*time.Second, updatesKey).Result()
	if err == redis.Nil {
		log.LoggerWContext(ctx).Info(fmt.Sprintf("Request %s Timed out", jobId))
	} else if err != nil {
		msg := "Problem waiting for update"
		log.LoggerWContext(ctx).Error(msg + ": " + err.Error())
	}

	h.handleStatus(w, r, p)
}

func (h *JobStatusHandler) jobStatusKey(jobId string) string {
	return jobId + "-Status"
}

func (h *JobStatusHandler) jobStatusUpdatesKey(jobId string) string {
	return h.jobStatusKey(jobId) + "-Updates"
}

func (h *JobStatusHandler) writeMessage(ctx context.Context, statusCode int, message string, w http.ResponseWriter) {
	w.WriteHeader(statusCode)
	res, _ := json.Marshal(map[string]interface{}{
		"message": message,
		"status":  statusCode,
	})
	fmt.Fprintf(w, string(res))
}

func (h *JobStatusHandler) keyExists(ctx context.Context, key string) (bool, error) {
	data, err := h.redis.Exists(ctx, key).Result()

	if err != nil {
		return false, err
	}

	return data == 1, err
}

func (h *JobStatusHandler) writeJobStatus(ctx context.Context, jobId string, w http.ResponseWriter) error {
	data, err := h.redis.HGetAll(ctx, h.jobStatusKey(jobId)).Result()

	if err != nil {
		msg := "Unable to get job status from redis database"
		h.writeMessage(ctx, http.StatusInternalServerError, msg, w)
		log.LoggerWContext(ctx).Error(msg + ": " + err.Error())
	} else {
		h.sendResults(w, data)
	}
	return err
}

func (h *JobStatusHandler) handleStatus(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()

	jobId := p.ByName("job_id")
	statusKey := h.jobStatusKey(jobId)

	if statusExists, err := h.keyExists(ctx, statusKey); err != nil {
		msg := "Unable to check if job status exists in redis database"
		h.writeMessage(ctx, http.StatusInternalServerError, msg, w)
		log.LoggerWContext(ctx).Error(msg + ": " + err.Error())
		return
	} else if statusExists {
		h.writeJobStatus(ctx, jobId, w)
		return
	}

	if jobExists, err := h.keyExists(ctx, jobId); err != nil {
		msg := "Unable to check if job exists in redis database"
		h.writeMessage(ctx, http.StatusInternalServerError, msg, w)
		log.LoggerWContext(ctx).Error(msg + ": " + err.Error())
	} else if jobExists {
		h.writeMessage(ctx, STATUS_PENDING, "In Progress", w)
	} else {
		// Job is not pending and no status found, it either has expired or never existed, return a 404
		h.writeMessage(ctx, http.StatusNotFound, "Unable to find pending, running or completed job status", w)
	}

}

func (h *JobStatusHandler) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	ctx := r.Context()

	defer panichandler.Http(ctx, w)

	// We always default to application/json
	w.Header().Set("Content-Type", "application/json")

	if handle, params, _ := h.router.Lookup(r.Method, r.URL.Path); handle != nil {
		handle(w, r, params)
		return nil
	}

	return next.ServeHTTP(w, r)
}

func (s *JobStatusHandler) UnmarshalCaddyfile(c *caddyfile.Dispenser) error {
	c.Next()
	return nil
}

var (
	_ caddy.Provisioner           = (*JobStatusHandler)(nil)
	_ caddy.CleanerUpper          = (*JobStatusHandler)(nil)
	_ caddy.Validator             = (*JobStatusHandler)(nil)
	_ caddyhttp.MiddlewareHandler = (*JobStatusHandler)(nil)
	_ caddyfile.Unmarshaler       = (*JobStatusHandler)(nil)
)
