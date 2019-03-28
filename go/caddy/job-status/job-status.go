package jobstatus

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/panichandler"
	"github.com/julienschmidt/httprouter"
)

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

	router := httprouter.New()
	router.GET("/api/v1/pfqueue/job/:job_id/status", jobStatus.handleStatus)
	router.GET("/api/v1/pfqueue/job/:job_id/status/poll", jobStatus.handleStatusPoll)

	jobStatus.router = router

	return jobStatus, nil
}

func (h JobStatusHandler) handleStatus(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	w.WriteHeader(http.StatusOK)
	res, _ := json.Marshal(map[string]string{
		"changeme": "yes please",
	})
	fmt.Fprintf(w, string(res))
}

func (h JobStatusHandler) handleStatusPoll(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	w.WriteHeader(http.StatusOK)
	res, _ := json.Marshal(map[string]string{
		"changeme": "yes please",
	})
	fmt.Fprintf(w, string(res))
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
