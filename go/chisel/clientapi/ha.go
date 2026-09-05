package clientapi

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	chshare "github.com/inverse-inc/packetfence/go/chisel/share"
	"github.com/inverse-inc/packetfence/go/chisel/share/tunnel"
)

// SetTunnel replaces the tunnel the API reports on and proxies to. HA mode
// (PFCONNECTOR_HA_VIP) creates a client, and therefore a tunnel, each time
// the host takes the VIP and drops it when the VIP leaves; nil means no
// tunnel, which the RADIUS authorize endpoint answers with the degraded
// realm.
func (api *API) SetTunnel(tun *tunnel.Tunnel) {
	api.tunnelMu.Lock()
	defer api.tunnelMu.Unlock()
	api.tunnel = tun
}

// Tunnel returns the current tunnel, or nil.
func (api *API) Tunnel() *tunnel.Tunnel {
	api.tunnelMu.RLock()
	defer api.tunnelMu.RUnlock()
	return api.tunnel
}

// TunnelActive reports whether there is a tunnel and its SSH connection is up.
func (api *API) TunnelActive() bool {
	tun := api.Tunnel()
	return tun != nil && tun.IsActive()
}

// apiTunnelState adapts the API's swappable tunnel to the tunnelState
// interface used by the cache refreshers.
type apiTunnelState struct {
	api *API
}

func (s *apiTunnelState) IsActive() bool { return s.api.TunnelActive() }

// HAStatus is the high-availability state of this connector host, reported in
// /api/v1/system/info as "ha" when PFCONNECTOR_HA_VIP is set. See
// docs/design/pfconnector-remote-ha.md.
type HAStatus struct {
	Enabled  bool   `json:"enabled"`
	VIP      string `json:"vip"`
	Hostname string `json:"hostname"`
	// State is "master" while this host holds the VIP and runs the tunnel,
	// "backup" otherwise.
	State string    `json:"state"`
	Since time.Time `json:"since"`
	// Peers are the other hosts of the pair as seen through their LAN
	// heartbeats to this host (only meaningful on the master: the backups
	// send, the master listens on the VIP).
	Peers []HAPeer `json:"peers"`
}

// HAPeer is one other host of the HA group, from its last heartbeat.
type HAPeer struct {
	Hostname string    `json:"hostname"`
	Address  string    `json:"address"`
	Version  string    `json:"version"`
	State    string    `json:"state"`
	Priority string    `json:"priority,omitempty"`
	LastSeen time.Time `json:"last_seen"`
	// Alive is true when a heartbeat arrived within haPeerTimeout.
	Alive bool `json:"alive"`
	// Cache mirror state reported by the peer (phase 4, hacache.go).
	CacheSyncState
}

// haPeerTimeout is how long a peer stays "alive" after its last heartbeat.
// Backups send every haHeartbeatInterval.
const (
	haHeartbeatInterval = 5 * time.Second
	haPeerTimeout       = 3 * haHeartbeatInterval
	// haHeartbeatMaxSkew bounds the age of a heartbeat timestamp (replay).
	haHeartbeatMaxSkew = 60 * time.Second
)

var (
	haStatusMu sync.RWMutex
	haStatus   *HAStatus
	haKey      []byte
	haPeers    = map[string]HAPeer{}
)

// SetHAState records the current HA state; called by the HA client loop.
func SetHAState(vip, state string) {
	haStatusMu.Lock()
	defer haStatusMu.Unlock()
	if haStatus != nil && haStatus.State == state && haStatus.VIP == vip {
		return
	}
	hostname, _ := os.Hostname()
	haStatus = &HAStatus{Enabled: true, VIP: vip, Hostname: hostname, State: state, Since: time.Now()}
}

// SetHASecret derives the keys that authenticate heartbeats and protect cache
// snapshots between the hosts of the group from the connector secret, which
// they all share.
func SetHASecret(secret string) {
	haStatusMu.Lock()
	defer haStatusMu.Unlock()
	haKey = HAKey(secret)
	setHACacheKey(secret)
}

// HAKey derives the heartbeat HMAC key from the connector secret.
func HAKey(secret string) []byte {
	sum := sha256.Sum256([]byte("pfconnector-ha-heartbeat:" + secret))
	return sum[:]
}

// HAStatusSnapshot returns a copy of the HA status with the peers' liveness
// evaluated now, or nil when HA is off.
func HAStatusSnapshot() *HAStatus {
	haStatusMu.RLock()
	defer haStatusMu.RUnlock()
	if haStatus == nil {
		return nil
	}
	copied := *haStatus
	copied.Peers = []HAPeer{}
	now := time.Now()
	for _, p := range haPeers {
		p.Alive = now.Sub(p.LastSeen) < haPeerTimeout
		copied.Peers = append(copied.Peers, p)
	}
	sort.Slice(copied.Peers, func(i, j int) bool { return copied.Peers[i].Address < copied.Peers[j].Address })
	return &copied
}

// HAHeartbeat is the body a backup host POSTs to the master's side-car API on
// the VIP (/api/v1/ha/heartbeat) every haHeartbeatInterval.
type HAHeartbeat struct {
	Hostname  string `json:"hostname"`
	Version   string `json:"version"`
	State     string `json:"state"`
	Priority  string `json:"priority,omitempty"`
	Timestamp int64  `json:"ts"`
	CacheSyncState
}

// haSignatureHeader carries hex(HMAC-SHA256(key, body)).
const haSignatureHeader = "X-PF-HA-Signature"

// SignHeartbeat returns the signature header value for a heartbeat body.
func SignHeartbeat(key, body []byte) string {
	mac := hmac.New(sha256.New, key)
	mac.Write(body)
	return hex.EncodeToString(mac.Sum(nil))
}

// SendHeartbeat posts this host's heartbeat to the master at vip:8081. Called
// by the HA client loop while this host is a backup.
func SendHeartbeat(ctx context.Context, vip string, secret string, hb HAHeartbeat) error {
	hb.Timestamp = time.Now().Unix()
	body, err := json.Marshal(hb)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, fmt.Sprintf("http://%s:8081/api/v1/ha/heartbeat", vip), bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set(haSignatureHeader, SignHeartbeat(HAKey(secret), body))
	res, err := haHeartbeatClient.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	io.Copy(io.Discard, res.Body)
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("heartbeat refused: HTTP %d", res.StatusCode)
	}
	return nil
}

var haHeartbeatClient = &http.Client{Timeout: 2 * time.Second}

// haHeartbeat is POST /api/v1/ha/heartbeat on the master. Not localhost-only:
// the backups reach it on the VIP over the site LAN. Authenticated by the
// HMAC of the body with a key derived from the connector secret, bounded by
// the timestamp in the body; refused (404) when HA is not enabled here.
func haHeartbeat(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		haStatusMu.RLock()
		enabled := haStatus != nil
		key := haKey
		haStatusMu.RUnlock()
		if !enabled || len(key) == 0 {
			http.NotFound(w, r)
			return
		}
		body, err := io.ReadAll(io.LimitReader(r.Body, 4096))
		if err != nil {
			http.Error(w, "unable to read body", http.StatusBadRequest)
			return
		}
		want := SignHeartbeat(key, body)
		got := r.Header.Get(haSignatureHeader)
		if len(got) != len(want) || !hmac.Equal([]byte(got), []byte(want)) {
			log.LoggerWContext(api.ctx).Warn(fmt.Sprintf("HA heartbeat from %s refused: bad signature", r.RemoteAddr))
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		var hb HAHeartbeat
		if err := json.Unmarshal(body, &hb); err != nil || hb.Hostname == "" {
			http.Error(w, "invalid heartbeat", http.StatusBadRequest)
			return
		}
		if skew := time.Since(time.Unix(hb.Timestamp, 0)); skew > haHeartbeatMaxSkew || skew < -haHeartbeatMaxSkew {
			http.Error(w, "stale heartbeat", http.StatusForbidden)
			return
		}
		addr := r.RemoteAddr
		if i := strings.LastIndex(addr, ":"); i > 0 {
			addr = addr[:i]
		}
		// Keyed by sender address: cloned VMs often share a hostname.
		haStatusMu.Lock()
		haPeers[addr] = HAPeer{Hostname: hb.Hostname, Address: addr, Version: hb.Version, State: hb.State, Priority: hb.Priority, LastSeen: time.Now(), CacheSyncState: hb.CacheSyncState}
		haStatusMu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})
}

// LocalHeartbeat builds this host's heartbeat.
func LocalHeartbeat(state string) HAHeartbeat {
	hostname, _ := os.Hostname()
	return HAHeartbeat{
		Hostname:       hostname,
		Version:        chshare.BuildVersion,
		State:          state,
		Priority:       os.Getenv("PFCONNECTOR_HA_PRIORITY"),
		CacheSyncState: cacheSyncSnapshot(),
	}
}
