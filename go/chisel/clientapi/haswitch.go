package clientapi

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
)

// Making another host of the HA group active from the admin UI
// (docs/design/pfconnector-remote-ha.md). Every host-level action (install,
// terminal, logs, upgrade, restart) reaches the host holding the VIP, so
// choosing a host means moving the VIP to it:
//
//  1. the cloud asks the master: POST /api/v1/ha/switch {"to": "<peer addr>"}
//  2. the master asks that peer, over the site LAN and HMAC-signed like the
//     heartbeat, to boost its VRRP priority: the peer writes haBoostValue into
//     the file keepalived tracks (track_file ha_boost, weight 1);
//  3. the master yields: it stops its keepalived for a few seconds, the VIP is
//     released and the boosted peer wins the election among the backups;
//  4. the old master's keepalived comes back as BACKUP (nopreempt), the new
//     master clears its boost once it holds the VIP.

var (
	// haBoostFile is the keepalived track_file; var/run is bind-mounted, the
	// generator creates it with 0.
	haBoostFile = sharedutils.EnvOrDefault("PFCONNECTOR_HA_BOOST_FILE", "/usr/local/pfconnector-remote/var/run/ha_boost")
	// haBoostValue is added to the peer's priority (priority + boost <= 254
	// for any configured priority up to 100; keepalived caps it anyway).
	haBoostValue = 150
	// haYieldDuration is how long the master keeps keepalived down so the
	// backups elect a new master (3 missed advertisements + margin).
	haYieldDuration = 6 * time.Second
	// haBoostTTL clears a boost that never led to a takeover.
	haBoostTTL = 60 * time.Second
)

// SetHABoost writes the tracked priority boost (0 clears it).
func SetHABoost(value int) error {
	return os.WriteFile(haBoostFile, []byte(strconv.Itoa(value)+"\n"), 0o644)
}

// haBoostRequest is what the master posts to the chosen peer.
type haBoostRequest struct {
	Boost     int   `json:"boost"`
	Timestamp int64 `json:"ts"`
}

// haBoost is POST /api/v1/ha/boost on a backup (not localhost-only, HMAC).
func haBoost(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		haStatusMu.RLock()
		enabled := haStatus != nil
		key := haKey
		haStatusMu.RUnlock()
		if !enabled || len(key) == 0 || !peerRequest(r) {
			http.NotFound(w, r)
			return
		}
		body, err := io.ReadAll(io.LimitReader(r.Body, 1024))
		if err != nil {
			http.Error(w, "unable to read body", http.StatusBadRequest)
			return
		}
		want := boostSignature(key, body)
		got := r.Header.Get(haSignatureHeader)
		if len(got) != len(want) || !hmac.Equal([]byte(got), []byte(want)) {
			log.LoggerWContext(api.ctx).Warn(fmt.Sprintf("HA boost request from %s refused: bad signature", r.RemoteAddr))
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		var req haBoostRequest
		if err := json.Unmarshal(body, &req); err != nil {
			http.Error(w, "invalid request", http.StatusBadRequest)
			return
		}
		if skew := time.Since(time.Unix(req.Timestamp, 0)); skew > haHeartbeatMaxSkew || skew < -haHeartbeatMaxSkew {
			http.Error(w, "stale request", http.StatusForbidden)
			return
		}
		if req.Boost < 0 || req.Boost > 254 {
			http.Error(w, "invalid boost", http.StatusBadRequest)
			return
		}
		if err := SetHABoost(req.Boost); err != nil {
			log.LoggerWContext(api.ctx).Error(fmt.Sprintf("HA: unable to write the priority boost: %s", err))
			http.Error(w, "unable to apply the boost", http.StatusInternalServerError)
			return
		}
		log.LoggerWContext(api.ctx).Info(fmt.Sprintf("HA: VRRP priority boost %d applied at the master's request (%s)", req.Boost, r.RemoteAddr))
		if req.Boost > 0 {
			// Safety net: a takeover that never happens must not leave this
			// host boosted forever.
			go func() {
				time.Sleep(haBoostTTL)
				haStatusMu.RLock()
				state := ""
				if haStatus != nil {
					state = haStatus.State
				}
				haStatusMu.RUnlock()
				if state != "master" {
					SetHABoost(0)
				}
			}()
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})
}

// boostSignature signs a boost body; its own domain so a captured heartbeat
// (which also unmarshals into haBoostRequest, with Boost=0) cannot be
// replayed to cancel a pending boost.
func boostSignature(key, body []byte) string {
	mac := hmac.New(sha256.New, key)
	mac.Write([]byte("boost:"))
	mac.Write(body)
	return hex.EncodeToString(mac.Sum(nil))
}

// sendBoost asks a peer to boost its priority.
func sendBoost(peer string, key []byte, boost int) error {
	body, _ := json.Marshal(haBoostRequest{Boost: boost, Timestamp: time.Now().Unix()})
	req, err := http.NewRequest(http.MethodPost, fmt.Sprintf("http://%s:8081/api/v1/ha/boost", peer), bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set(haSignatureHeader, boostSignature(key, body))
	res, err := haHeartbeatClient.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	io.Copy(io.Discard, res.Body)
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("peer answered HTTP %d", res.StatusCode)
	}
	return nil
}

// yieldVIP stops keepalived for haYieldDuration so the backups elect a new
// master, then brings it back (state BACKUP, nopreempt). No-op outside the
// container.
func yieldVIP(logf func(string, ...interface{})) {
	if _, err := os.Stat(keepalivedServiceDir); err != nil {
		logf("HA: keepalived service not found, cannot yield the VIP")
		return
	}
	if out, err := exec.Command(s6svcBinary, "-d", keepalivedServiceDir).CombinedOutput(); err != nil {
		logf("HA: unable to stop keepalived to yield the VIP: %s: %s", err, strings.TrimSpace(string(out)))
		return
	}
	logf("HA: keepalived stopped, yielding the VIP")
	time.Sleep(haYieldDuration)
	if out, err := exec.Command(s6svcBinary, "-u", keepalivedServiceDir).CombinedOutput(); err != nil {
		logf("HA: unable to restart keepalived after yielding: %s: %s", err, strings.TrimSpace(string(out)))
		return
	}
	logf("HA: keepalived restarted as backup")
}

const (
	keepalivedServiceDir = "/run/service/keepalived"
	s6svcBinary          = "/command/s6-svc"
)

// haSwitch is POST /api/v1/ha/switch {"to": "<peer address>"} (localhost-only,
// reached by the cloud through the tunnel). Only the master can switch, and
// only to a peer that reported alive.
func haSwitch(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			To string `json:"to"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || net.ParseIP(strings.TrimSpace(req.To)) == nil {
			http.Error(w, "A peer IP address is required", http.StatusBadRequest)
			return
		}
		to := strings.TrimSpace(req.To)
		status := HAStatusSnapshot()
		if status == nil {
			http.Error(w, "High availability is not enabled on this connector", http.StatusConflict)
			return
		}
		if status.State != "master" {
			http.Error(w, "Only the host holding the virtual IP can hand it over", http.StatusConflict)
			return
		}
		var peer *HAPeer
		for i := range status.Peers {
			if status.Peers[i].Address == to {
				peer = &status.Peers[i]
			}
		}
		if peer == nil || !peer.Alive {
			http.Error(w, fmt.Sprintf("Host %s is not a reporting member of the HA group", to), http.StatusNotFound)
			return
		}
		haStatusMu.RLock()
		key := haKey
		haStatusMu.RUnlock()
		if err := sendBoost(to, key, haBoostValue); err != nil {
			log.LoggerWContext(api.ctx).Error(fmt.Sprintf("HA: unable to boost %s before yielding: %s", to, err))
			http.Error(w, fmt.Sprintf("Unable to reach host %s to prepare the switch: %s", to, err), http.StatusBadGateway)
			return
		}
		log.LoggerWContext(api.ctx).Info(fmt.Sprintf("HA: switch requested, handing the VIP %s over to %s", status.VIP, to))
		// Answer first: yielding closes our tunnel, and this reply travels
		// through it.
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": fmt.Sprintf("Handing the virtual IP over to %s", to), "to": to})
		go func() {
			time.Sleep(500 * time.Millisecond)
			yieldVIP(func(f string, a ...interface{}) { log.LoggerWContext(api.ctx).Info(fmt.Sprintf(f, a...)) })
		}()
	})
}
