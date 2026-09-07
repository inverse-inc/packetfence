package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"sort"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/connector"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"golang.org/x/sync/errgroup"
)

// Connectors topology: one call returning, for every configured connector,
// whether its tunnel is up and the tunnel's transport counters (bytes in each
// direction, keepalive round trip, open channels). The admin UI polls it and
// derives the throughput from two consecutive samples, so the counters are
// cumulative and carry their sampling time.

// topologyConnector is one node of the graph.
type topologyConnector struct {
	ID          string   `json:"id"`
	Description string   `json:"description"`
	Networks    []string `json:"networks"`
	HaVip       string   `json:"ha_vip,omitempty"`
	Connected   bool     `json:"connected"`
	RemoteIPs   []string `json:"remote_ips"`
	// Stats mirrors tunnel.StatsSnapshot; nil when no server holds a tunnel
	// for the connector or the server could not be reached.
	Stats map[string]interface{} `json:"stats,omitempty"`
	// HA mirrors the "ha" block of the active host's system info (VIP,
	// active host, standby peers with their liveness); only for connected
	// connectors with a VIP, and cached a few seconds since it costs a
	// round trip to the site.
	HA    map[string]interface{} `json:"ha,omitempty"`
	Error string                 `json:"error,omitempty"`
}

// haCacheEntry is a cached "ha" block of one connector.
type haCacheEntry struct {
	at time.Time
	ha map[string]interface{}
}

var (
	haCache    sync.Map // connector id -> haCacheEntry
	haCacheTTL = 15 * time.Second
)

// connectorHA returns the HA block of a connected connector's active host,
// from the cache when fresh enough. nil when the host has no HA or does not
// answer.
func (h APIHandler) connectorHA(conn *connector.Connector, id string) map[string]interface{} {
	if v, ok := haCache.Load(id); ok {
		if e := v.(haCacheEntry); time.Since(e.at) < haCacheTTL {
			return e.ha
		}
	}
	var ha map[string]interface{}
	if info, err := h.callConnectorRemoteAPI(conn, "GET", "/api/v1/system/info", nil); err == nil {
		if block, ok := info["ha"].(map[string]interface{}); ok {
			ha = block
		}
	}
	haCache.Store(id, haCacheEntry{at: time.Now(), ha: ha})
	return ha
}

type topologyReply struct {
	GeneratedAt time.Time           `json:"generated_at"`
	Connectors  []topologyConnector `json:"connectors"`
}

const (
	topologyFanout  = 8
	topologyTimeout = 5 * time.Second
)

// pfconnectorTopology is GET /api/v1/pfconnector-remotes/topology.
func (h APIHandler) pfconnectorTopology() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		configs := pfconfigdriver.Connectors{}
		if err := pfconfigdriver.FetchDecodeSocket(r.Context(), &configs); err != nil {
			http.Error(w, "Unable to fetch the connectors configuration", http.StatusInternalServerError)
			return
		}
		container := connector.NewConnectorsContainer(h.ctx)
		all := container.All(r.Context())

		ids := make([]string, 0, len(all))
		for id := range all {
			// The implicit local connector has no tunnel.
			if id == "local_connector" {
				continue
			}
			ids = append(ids, id)
		}
		sort.Strings(ids)

		reply := topologyReply{GeneratedAt: time.Now(), Connectors: make([]topologyConnector, len(ids))}
		var mu sync.Mutex
		eg, ctx := errgroup.WithContext(r.Context())
		eg.SetLimit(topologyFanout)
		for i, id := range ids {
			i, id, conn := i, id, all[id]
			node := topologyConnector{ID: id, Networks: []string{}, RemoteIPs: []string{}}
			if cfg, ok := configs.Element[id]; ok {
				node.Description = cfg.Description
				node.HaVip = cfg.HaVip
				if cfg.Networks != nil {
					node.Networks = cfg.Networks
				}
			}
			eg.Go(func() error {
				cctx, cancel := context.WithTimeout(ctx, topologyTimeout)
				defer cancel()
				detail := connectorDetail{}
				err := conn.ServerCall(cctx, "GET", "/api/v1/pfconnector/connector-detail?connector-id="+url.QueryEscape(id), &detail)
				if err != nil {
					// A connector that has never connected has no server
					// entry: not connected, no error worth showing.
					log.LoggerWContext(r.Context()).Debug("topology: " + id + ": " + err.Error())
					node.Error = "unreachable"
				} else {
					node.Connected = detail.Connected
					if detail.RemoteIPs != nil {
						node.RemoteIPs = detail.RemoteIPs
					}
					node.Stats = detail.Stats
					if node.Connected && node.HaVip != "" {
						node.HA = h.connectorHA(conn, id)
					}
				}
				mu.Lock()
				reply.Connectors[i] = node
				mu.Unlock()
				return nil
			})
		}
		eg.Wait()

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(reply)
	})
}
