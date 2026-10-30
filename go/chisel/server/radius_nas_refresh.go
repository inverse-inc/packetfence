package chserver

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"sort"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/chisel/share/tunnel"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

// A switch or a connector saved in PacketFence changes the RADIUS clients a
// connector-remote renders from the switches behind it (remote-radius-nas),
// and its FreeRADIUS only reads them at start. PacketFence posts
// {"connector_id": ...} to /api/v1/pfconnector/refresh-radius-nas after such a
// save (pf::connector::refresh_radius_nas); the server coalesces the requests
// of a save burst per connector and, after a quiet period, asks the
// connector-remote through its tunnel to re-run its sync scripts
// (POST /api/v1/system/refresh-config, clientapi), which restarts its RADIUS
// server only when the rendered configuration changed. A connector without a
// tunnel syncs when it connects; the standby hosts of an HA group follow
// their master on their own.

var (
	// radiusNasRefreshDebounce is the quiet period after the last request
	// for a connector before it is asked to refresh.
	radiusNasRefreshDebounce = sharedutils.EnvOrDefaultDuration("PFCONNECTOR_SERVER_NAS_REFRESH_DEBOUNCE", 2*time.Second)
	// radiusNasRefreshTimeout bounds the call through the tunnel (the
	// connector answers before running its scripts).
	radiusNasRefreshTimeout = 15 * time.Second
	// connectorRefreshConfigPath is the connector-remote API endpoint that
	// re-runs the sync scripts (clientapi systemRefreshConfig).
	connectorRefreshConfigPath = "/api/v1/system/refresh-config"
)

// refreshDebouncer calls fire(id) once per id, delay after the last Request
// for that id.
type refreshDebouncer struct {
	mu     sync.Mutex
	delay  time.Duration
	fire   func(id string)
	timers map[string]*time.Timer
}

func newRefreshDebouncer(delay time.Duration, fire func(id string)) *refreshDebouncer {
	return &refreshDebouncer{delay: delay, fire: fire, timers: map[string]*time.Timer{}}
}

// Request (re)starts the quiet period of id.
func (d *refreshDebouncer) Request(id string) {
	d.mu.Lock()
	defer d.mu.Unlock()
	if timer, ok := d.timers[id]; ok && timer.Stop() {
		timer.Reset(d.delay)
		return
	}
	// No timer, or one that already fired and is about to run (its callback
	// finds another timer in the map and leaves it alone): arm a new one.
	var timer *time.Timer
	timer = time.AfterFunc(d.delay, func() {
		d.mu.Lock()
		if d.timers[id] == timer {
			delete(d.timers, id)
		}
		d.mu.Unlock()
		d.fire(id)
	})
	d.timers[id] = timer
}

// radiusNasRefresher coalesces the refresh requests and runs them. One per
// process: the server is started once per listening host and both share the
// tunnels.
var radiusNasRefresher = newRefreshDebouncer(radiusNasRefreshDebounce, refreshConnectorRadiusNas)

// refreshConnectorRadiusNas asks one connector-remote to refresh its
// configuration, through its tunnel.
func refreshConnectorRadiusNas(connectorID string) {
	ctx, cancel := context.WithTimeout(context.Background(), radiusNasRefreshTimeout)
	defer cancel()
	o, ok := activeTunnels.Load(connectorID)
	tun, _ := o.(*tunnel.Tunnel)
	if !ok || tun == nil || !tun.IsActive() {
		log.LoggerWContext(ctx).Info(fmt.Sprintf("refresh-radius-nas: no active tunnel for connector %s, it syncs its RADIUS clients when it connects", connectorID))
		return
	}
	status, body, err := tunnelRequest(ctx, tun, http.MethodPost, connectorRefreshConfigPath, nil)
	switch {
	case err != nil:
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("refresh-radius-nas: unable to ask connector %s to refresh its configuration: %s", connectorID, err))
	case status == http.StatusNotFound || status == http.StatusNotImplemented:
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("refresh-radius-nas: connector %s cannot refresh its configuration on request (answered %d): restart it to reload its RADIUS clients", connectorID, status))
	case status >= 300:
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("refresh-radius-nas: connector %s answered %d: %s", connectorID, status, string(body)))
	default:
		log.LoggerWContext(ctx).Info(fmt.Sprintf("refresh-radius-nas: connector %s is refreshing its configuration", connectorID))
	}
}

// handleRefreshRadiusNas accepts a refresh request for one connector
// ({"connector_id": ...}) or, with an empty or absent body, for every
// connector with an active tunnel. Answers 202: the refresh is debounced and
// asynchronous.
func (s *Server) handleRefreshRadiusNas(w http.ResponseWriter, req *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if req.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusMethodNotAllowed, Message: "POST only"})
		return
	}
	payload := struct {
		ConnectorID string `json:"connector_id"`
	}{}
	if body, _ := io.ReadAll(io.LimitReader(req.Body, 4096)); len(body) > 0 {
		if err := json.Unmarshal(body, &payload); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusBadRequest, Message: fmt.Sprintf("Unable to decode JSON payload: %s", err)})
			return
		}
	}

	ids := []string{}
	if payload.ConnectorID != "" {
		ids = append(ids, payload.ConnectorID)
	} else {
		activeTunnels.Range(func(k, v any) bool {
			if id, ok := k.(string); ok {
				if tun, ok := v.(*tunnel.Tunnel); ok && tun.IsActive() {
					ids = append(ids, id)
				}
			}
			return true
		})
		sort.Strings(ids)
	}
	for _, id := range ids {
		radiusNasRefresher.Request(id)
	}
	log.LoggerWContext(req.Context()).Info(fmt.Sprintf("refresh-radius-nas: refresh requested for %d connector(s)", len(ids)))
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(map[string]interface{}{"message": "RADIUS clients refresh scheduled", "connectors": ids})
}
