package jobstatus

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"git.inverse.ca/inverse/fingerbank-processor/sharedutils"

	"github.com/davecgh/go-spew/spew"
	"github.com/go-redis/redis"

	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/julienschmidt/httprouter"
)

const REDIS_HOST = "localhost"
const REDIS_PORT = 6380

// Register the plugin in caddy
func init() {
	caddy.RegisterPlugin("job-status", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}

type JobStatusHandler struct {
	Next   httpserver.Handler
	router *httprouter.Router
	redis  *redis.Client
}

// Setup the api-aaa middleware
// Also loads the pfconfig resources and registers them in the pool
func setup(c *caddy.Controller) error {
	ctx := log.LoggerNewContext(context.Background())

	jobStatus, err := buildJobStatusHandler(ctx)

	if err != nil {
		return err
	}

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		jobStatus.Next = next
		return jobStatus
	})

	return nil
}

// Build the JobStatusHandler which will initialize the cache and instantiate the router along with its routes
func buildJobStatusHandler(ctx context.Context) (JobStatusHandler, error) {

	jobStatus := JobStatusHandler{}

	jobStatus.redis = redis.NewClient(&redis.Options{
		Addr: sharedutils.CleanRedisUri(fmt.Sprintf("redis://%s:%d", REDIS_HOST, REDIS_PORT)),
	})

	router := httprouter.New()
	router.GET("/api/v1/pfqueue/job/:job_id/status", jobStatus.handleStatus)
	router.GET("/api/v1/pfqueue/job/:job_id/status/poll", jobStatus.handleStatusPoll)

	jobStatus.router = router

	spew.Dump(jobStatus.redis)

	return jobStatus, nil
}

func (h JobStatusHandler) handleStatusPoll(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	w.WriteHeader(http.StatusOK)
	res, _ := json.Marshal(map[string]string{
		"changeme": "yes please",
	})
	fmt.Fprintf(w, string(res))
}

func (h JobStatusHandler) jobStatusKey(jobId string) string {
	return jobId + "-Status"
}

func (h JobStatusHandler) writeMessage(ctx context.Context, message string, w http.ResponseWriter) {
	res, _ := json.Marshal(map[string]string{
		"message": message,
	})
	fmt.Fprintf(w, string(res))
}

func (h JobStatusHandler) keyExists(ctx context.Context, key string) (bool, error) {
	data, err := h.redis.Exists(key).Result()

	if err != nil {
		return false, err
	}

	return data == 1, err
}

func (h JobStatusHandler) writeJobStatus(ctx context.Context, jobId string, w http.ResponseWriter) error {
	data, err := h.redis.HGetAll(h.jobStatusKey(jobId)).Result()

	if err != nil {
		msg := "Unable to get job status from redis database"
		h.writeMessage(ctx, msg, w)
		log.LoggerWContext(ctx).Error(msg)
		w.WriteHeader(http.StatusInternalServerError)
	} else {
		res, _ := json.Marshal(data)
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, string(res))
	}
	return err
}

func (h JobStatusHandler) handleStatus(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	ctx := r.Context()

	jobId := p.ByName("job_id")
	statusKey := h.jobStatusKey(jobId)

	if jobExists, err := h.keyExists(ctx, jobId); err != nil {
		msg := "Unable to check if job exists in redis database"
		h.writeMessage(ctx, msg, w)
		log.LoggerWContext(ctx).Error(msg)
		w.WriteHeader(http.StatusInternalServerError)
	} else if jobExists {
		res, _ := json.Marshal(map[string]string{
			"status": "Pending",
		})
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, string(res))
		return
	}

	if statusExists, err := h.keyExists(ctx, statusKey); err != nil {
		msg := "Unable to check if job status exists in redis database"
		h.writeMessage(ctx, msg, w)
		log.LoggerWContext(ctx).Error(msg)
		w.WriteHeader(http.StatusInternalServerError)
	} else if statusExists {
		h.writeJobStatus(ctx, jobId, w)
	} else {
		// Job is not pending and no status found, it either has expired or never existed, return a 404
		h.writeMessage(ctx, "Unable to find pending, running or completed job status", w)
		w.WriteHeader(http.StatusNotFound)
	}
}

func (h JobStatusHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	ctx := r.Context()

	defer panichandler.Http(ctx, w)

	// We always default to application/json
	w.Header().Set("Content-Type", "application/json")

	if handle, params, _ := h.router.Lookup(r.Method, r.URL.Path); handle != nil {
		handle(w, r, params)
		return 0, nil
	} else {
		return h.Next.ServeHTTP(w, r)
	}

}
