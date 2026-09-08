package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"strconv"
	"sync"
	"time"

	"github.com/inverse-inc/packetfence/go/connector"
	"golang.org/x/sync/errgroup"
)

// Traffic history of the tunnels for the topology charts: one call returns,
// for every connector (or the one given), the rate series the pfconnector
// server holding its tunnel recorded (chisel/server/traffic_history.go).

type trafficReply struct {
	SinceSeconds int                        `json:"since_s"`
	GeneratedAt  time.Time                  `json:"generated_at"`
	Connectors   map[string]json.RawMessage `json:"connectors"`
}

// pfconnectorTraffic is GET /api/v1/pfconnector-remotes/traffic?since=<seconds>[&connector=<id>].
func (h APIHandler) pfconnectorTraffic() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		since := 3600
		if v := r.URL.Query().Get("since"); v != "" {
			n, err := strconv.Atoi(v)
			if err != nil || n <= 0 || n > 3600 {
				http.Error(w, "since must be 1..3600 seconds", http.StatusBadRequest)
				return
			}
			since = n
		}
		container := connector.NewConnectorsContainer(h.ctx)
		targets := map[string]*connector.Connector{}
		if id := r.URL.Query().Get("connector"); id != "" {
			conn := container.Get(r.Context(), id)
			if conn == nil {
				http.Error(w, "Unknown PFconnector ID", http.StatusNotFound)
				return
			}
			targets[id] = conn
		} else {
			for id, conn := range container.All(r.Context()) {
				if id != "local_connector" {
					targets[id] = conn
				}
			}
		}

		reply := trafficReply{SinceSeconds: since, GeneratedAt: time.Now(), Connectors: map[string]json.RawMessage{}}
		var mu sync.Mutex
		eg, ctx := errgroup.WithContext(r.Context())
		eg.SetLimit(topologyFanout)
		for id, conn := range targets {
			id, conn := id, conn
			eg.Go(func() error {
				cctx, cancel := context.WithTimeout(ctx, topologyTimeout)
				defer cancel()
				var series json.RawMessage
				// 404 (no history yet, connector never connected) is simply
				// absent from the reply.
				if err := conn.ServerCall(cctx, "GET", "/api/v1/pfconnector/traffic-history?connector-id="+url.QueryEscape(id)+"&since="+strconv.Itoa(since), &series); err == nil && len(series) > 0 {
					mu.Lock()
					reply.Connectors[id] = series
					mu.Unlock()
				}
				return nil
			})
		}
		eg.Wait()
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(reply)
	})
}
