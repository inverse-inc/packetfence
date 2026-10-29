package chserver

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/chisel/share/tunnel"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

// Invalidation of the RADIUS replies a connector-remote caches (cache-first
// mode): when a device's access changes, PacketFence posts its MAC here
// (pf::connector::radius_cache, {"connector_ids": [...], "macs": [...]}),
// and the server asks each connector, through its tunnel, to drop the
// device's entries (POST /api/v1/radius/cache/invalidate on the connector's
// local API), so the device's next request is proxied to PacketFence.
//
// Two modes: asynchronous (202), where the requests of a burst (a bulk
// deregistration) are coalesced per connector for a short delay and sent as
// one list; and synchronous (200), used right before a CoA/Disconnect so the
// forced re-authentication is proxied, where the handler waits for the
// connectors. A delete that cannot be delivered (no tunnel, error, old
// connector) is kept for a while and replayed when the connector connects.

var (
	// radiusCacheInvalidateDelay is the coalescing delay of the asynchronous
	// mode.
	radiusCacheInvalidateDelay = sharedutils.EnvOrDefaultDuration("PFCONNECTOR_SERVER_RADCACHE_INVALIDATE_DELAY", 300*time.Millisecond)
	// radiusCacheInvalidateBatch flushes a connector's batch early when it
	// reaches that many devices; also the chunk size of one tunnel call.
	radiusCacheInvalidateBatch = 1000
	// radiusCacheInvalidateTimeout bounds one tunnel call.
	radiusCacheInvalidateTimeout = 10 * time.Second
	// radiusCacheSyncTimeout bounds a synchronous request as a whole.
	radiusCacheSyncTimeout = 5 * time.Second
	// radiusCachePendingTTL is how long an undelivered invalidation is kept
	// for the connector's next connection (the connector's own cache-first
	// freshness bounds the staleness past that).
	radiusCachePendingTTL = sharedutils.EnvOrDefaultDuration("PFCONNECTOR_SERVER_RADCACHE_PENDING_TTL", 15*time.Minute)
	// radiusCachePendingMax caps the pending devices per connector.
	radiusCachePendingMax = 10000
	// connectorRadiusCachePath is the connector-remote API endpoint.
	connectorRadiusCachePath = "/api/v1/radius/cache/invalidate"
)

var macRe = regexp.MustCompile(`^[0-9a-f]{2}(:[0-9a-f]{2}){5}$`)

// normalizeMac lowercases and reformats a MAC to aa:bb:cc:dd:ee:ff, false
// when it is not one.
func normalizeMac(mac string) (string, bool) {
	hex := strings.NewReplacer(":", "", "-", "", ".", "").Replace(strings.ToLower(strings.TrimSpace(mac)))
	if len(hex) != 12 {
		return "", false
	}
	var b strings.Builder
	for i := 0; i < 12; i += 2 {
		if i > 0 {
			b.WriteByte(':')
		}
		b.WriteString(hex[i : i+2])
	}
	out := b.String()
	return out, macRe.MatchString(out)
}

// invalidationSender delivers one list of MACs to one connector; it is a
// variable so the tests swap it.
type invalidationSender func(connectorID string, macs []string) error

// pendingInvalidations remembers, per connector, the devices whose
// invalidation could not be delivered, until the connector connects again or
// the TTL expires.
type pendingInvalidations struct {
	mu   sync.Mutex
	ttl  time.Duration
	max  int
	macs map[string]map[string]time.Time // connectorID -> mac -> expiry
}

func newPendingInvalidations(ttl time.Duration, max int) *pendingInvalidations {
	return &pendingInvalidations{ttl: ttl, max: max, macs: map[string]map[string]time.Time{}}
}

// Remember keeps the MACs for the connector (the oldest dropped past max).
func (p *pendingInvalidations) Remember(connectorID string, macs []string) {
	p.mu.Lock()
	defer p.mu.Unlock()
	set := p.macs[connectorID]
	if set == nil {
		set = map[string]time.Time{}
		p.macs[connectorID] = set
	}
	expiry := time.Now().Add(p.ttl)
	for _, mac := range macs {
		set[mac] = expiry
	}
	for len(set) > p.max {
		oldestMac, oldest := "", time.Time{}
		for mac, exp := range set {
			if oldest.IsZero() || exp.Before(oldest) {
				oldestMac, oldest = mac, exp
			}
		}
		delete(set, oldestMac)
	}
}

// Take returns and forgets the connector's unexpired pending MACs.
func (p *pendingInvalidations) Take(connectorID string) []string {
	p.mu.Lock()
	defer p.mu.Unlock()
	set := p.macs[connectorID]
	delete(p.macs, connectorID)
	now := time.Now()
	out := []string{}
	for mac, exp := range set {
		if exp.After(now) {
			out = append(out, mac)
		}
	}
	sort.Strings(out)
	return out
}

// invalidationBatcher coalesces the asynchronous requests per connector.
type invalidationBatcher struct {
	mu      sync.Mutex
	delay   time.Duration
	max     int
	send    invalidationSender
	pending *pendingInvalidations
	batches map[string]map[string]struct{}
	timers  map[string]*time.Timer
}

func newInvalidationBatcher(delay time.Duration, max int, send invalidationSender, pending *pendingInvalidations) *invalidationBatcher {
	return &invalidationBatcher{
		delay:   delay,
		max:     max,
		send:    send,
		pending: pending,
		batches: map[string]map[string]struct{}{},
		timers:  map[string]*time.Timer{},
	}
}

// Add queues the MACs for the connector; the batch leaves after the delay
// following the last Add, or at once when it is full.
func (b *invalidationBatcher) Add(connectorID string, macs []string) {
	b.mu.Lock()
	set := b.batches[connectorID]
	if set == nil {
		set = map[string]struct{}{}
		b.batches[connectorID] = set
	}
	for _, mac := range macs {
		set[mac] = struct{}{}
	}
	if len(set) >= b.max {
		if timer, ok := b.timers[connectorID]; ok {
			timer.Stop()
			delete(b.timers, connectorID)
		}
		b.mu.Unlock()
		b.flush(connectorID)
		return
	}
	if timer, ok := b.timers[connectorID]; ok && timer.Stop() {
		timer.Reset(b.delay)
		b.mu.Unlock()
		return
	}
	var timer *time.Timer
	timer = time.AfterFunc(b.delay, func() {
		b.mu.Lock()
		if b.timers[connectorID] == timer {
			delete(b.timers, connectorID)
		}
		b.mu.Unlock()
		b.flush(connectorID)
	})
	b.timers[connectorID] = timer
	b.mu.Unlock()
}

// flush sends the connector's batch; what cannot be delivered is kept pending.
func (b *invalidationBatcher) flush(connectorID string) {
	b.mu.Lock()
	set := b.batches[connectorID]
	delete(b.batches, connectorID)
	b.mu.Unlock()
	if len(set) == 0 {
		return
	}
	macs := make([]string, 0, len(set))
	for mac := range set {
		macs = append(macs, mac)
	}
	sort.Strings(macs)
	b.deliver(connectorID, macs)
}

// deliver sends the MACs in chunks, remembering the undelivered ones.
func (b *invalidationBatcher) deliver(connectorID string, macs []string) {
	for start := 0; start < len(macs); start += b.max {
		end := min(start+b.max, len(macs))
		chunk := macs[start:end]
		if err := b.send(connectorID, chunk); err != nil {
			log.LoggerWContext(context.Background()).Warn(fmt.Sprintf("radius-cache: %d invalidation(s) for connector %s kept for its next connection: %s", len(chunk), connectorID, err))
			b.pending.Remember(connectorID, chunk)
		}
	}
}

// FlushPending replays the invalidations kept for a connector that just
// connected; the first channel open can race the handshake, hence the
// retries.
func (b *invalidationBatcher) FlushPending(connectorID string) {
	macs := b.pending.Take(connectorID)
	if len(macs) == 0 {
		return
	}
	var err error
	for attempt := 0; attempt < 3; attempt++ {
		if attempt > 0 {
			time.Sleep(5 * time.Second)
		}
		if err = b.send(connectorID, macs); err == nil {
			log.LoggerWContext(context.Background()).Info(fmt.Sprintf("radius-cache: replayed %d pending invalidation(s) to connector %s", len(macs), connectorID))
			return
		}
	}
	log.LoggerWContext(context.Background()).Warn(fmt.Sprintf("radius-cache: unable to replay %d pending invalidation(s) to connector %s: %s", len(macs), connectorID, err))
	b.pending.Remember(connectorID, macs)
}

// sendRadiusCacheInvalidation asks one connector-remote, through its tunnel,
// to drop the cached replies of the devices.
func sendRadiusCacheInvalidation(connectorID string, macs []string) error {
	o, ok := activeTunnels.Load(connectorID)
	tun, _ := o.(*tunnel.Tunnel)
	if !ok || tun == nil || !tun.IsActive() {
		return fmt.Errorf("no active tunnel")
	}
	ctx, cancel := context.WithTimeout(context.Background(), radiusCacheInvalidateTimeout)
	defer cancel()
	body, _ := json.Marshal(map[string][]string{"macs": macs})
	status, reply, err := tunnelRequest(ctx, tun, http.MethodPost, connectorRadiusCachePath, body)
	switch {
	case err != nil:
		return err
	case status == http.StatusNotFound:
		return fmt.Errorf("the connector does not support cache invalidation (answered 404), upgrade it")
	case status >= 300:
		return fmt.Errorf("the connector answered %d: %s", status, strings.TrimSpace(string(reply)))
	}
	log.LoggerWContext(ctx).Info(fmt.Sprintf("radius-cache: connector %s dropped the cached replies of %d device(s)", connectorID, len(macs)))
	return nil
}

// radiusCacheInvalidator is the process-wide batcher (the server is started
// once per listening host, both share the tunnels).
var radiusCacheInvalidator = newInvalidationBatcher(radiusCacheInvalidateDelay, radiusCacheInvalidateBatch,
	sendRadiusCacheInvalidation, newPendingInvalidations(radiusCachePendingTTL, radiusCachePendingMax))

// connectedConnectorIDs lists the connectors with an active tunnel on this
// instance, sorted.
func connectedConnectorIDs() []string {
	ids := []string{}
	activeTunnels.Range(func(k, v any) bool {
		if id, ok := k.(string); ok {
			if tun, ok := v.(*tunnel.Tunnel); ok && tun.IsActive() {
				ids = append(ids, id)
			}
		}
		return true
	})
	sort.Strings(ids)
	return ids
}

// handleRadiusCacheInvalidate is POST /api/v1/pfconnector/radius-cache-invalidate
// {"connector_ids": [...], "macs": [...], "sync": false}. Empty connector_ids
// means every connector connected to this instance.
func (s *Server) handleRadiusCacheInvalidate(w http.ResponseWriter, req *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if req.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusMethodNotAllowed, Message: "POST only"})
		return
	}
	payload := struct {
		ConnectorIDs []string `json:"connector_ids"`
		Macs         []string `json:"macs"`
		Sync         bool     `json:"sync"`
	}{}
	if err := json.NewDecoder(io.LimitReader(req.Body, 1<<20)).Decode(&payload); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusBadRequest, Message: fmt.Sprintf("Unable to decode JSON payload: %s", err)})
		return
	}
	macs := []string{}
	seen := map[string]bool{}
	for _, m := range payload.Macs {
		mac, ok := normalizeMac(m)
		if !ok {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusBadRequest, Message: fmt.Sprintf("%q is not a MAC address", m)})
			return
		}
		if !seen[mac] {
			seen[mac] = true
			macs = append(macs, mac)
		}
	}
	if len(macs) == 0 {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(unifiedapiclient.ErrorReply{Status: http.StatusBadRequest, Message: "macs is required"})
		return
	}
	ids := payload.ConnectorIDs
	if len(ids) == 0 {
		ids = connectedConnectorIDs()
	}
	l := log.LoggerWContext(req.Context())

	if payload.Sync {
		type result struct {
			Status  int    `json:"status,omitempty"`
			Devices int    `json:"devices,omitempty"`
			Error   string `json:"error,omitempty"`
		}
		results := map[string]result{}
		var mu sync.Mutex
		var wg sync.WaitGroup
		done := make(chan struct{})
		for _, id := range ids {
			wg.Add(1)
			go func(id string) {
				defer wg.Done()
				err := radiusCacheInvalidator.send(id, macs)
				mu.Lock()
				defer mu.Unlock()
				if err != nil {
					results[id] = result{Error: err.Error()}
					radiusCacheInvalidator.pending.Remember(id, macs)
					return
				}
				results[id] = result{Status: http.StatusOK, Devices: len(macs)}
			}(id)
		}
		go func() { wg.Wait(); close(done) }()
		select {
		case <-done:
		case <-time.After(radiusCacheSyncTimeout):
			l.Warn(fmt.Sprintf("radius-cache: synchronous invalidation of %d device(s) still running after %s", len(macs), radiusCacheSyncTimeout))
		}
		mu.Lock()
		out := map[string]result{}
		for id, r := range results {
			out[id] = r
		}
		mu.Unlock()
		for _, id := range ids {
			if _, ok := out[id]; !ok {
				out[id] = result{Error: "timeout"}
			}
		}
		l.Info(fmt.Sprintf("radius-cache: synchronous invalidation of %d device(s) on %d connector(s)", len(macs), len(ids)))
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]interface{}{"results": out})
		return
	}

	scheduled, noTunnel := []string{}, []string{}
	for _, id := range ids {
		if o, ok := activeTunnels.Load(id); ok {
			if tun, ok := o.(*tunnel.Tunnel); ok && tun.IsActive() {
				scheduled = append(scheduled, id)
				radiusCacheInvalidator.Add(id, macs)
				continue
			}
		}
		noTunnel = append(noTunnel, id)
		radiusCacheInvalidator.pending.Remember(id, macs)
	}
	l.Info(fmt.Sprintf("radius-cache: invalidation of %d device(s) scheduled on %d connector(s), kept for %d without a tunnel", len(macs), len(scheduled), len(noTunnel)))
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(map[string]interface{}{"message": "RADIUS cache invalidation scheduled", "scheduled": scheduled, "no_tunnel": noTunnel})
}
