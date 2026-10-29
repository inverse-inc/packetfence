package clientapi

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/inverse-inc/go-utils/log"
)

// Invalidation of cached RADIUS replies, requested by PacketFence through the
// pfconnector server (POST /api/v1/radius/cache/invalidate {"macs": [...]})
// when a device's access changed: its entries are deleted from connector-cache
// (every switch and SSID), so its next request is proxied to PacketFence and
// cached again, instead of being answered from the cache (cache-first mode).

const (
	// radiusCacheInvalidateMaxMacs bounds one request (the server chunks
	// bigger invalidations).
	radiusCacheInvalidateMaxMacs = 1000
	radiusCacheInvalidateMaxBody = 256 * 1024
)

// radcacheDeleteClient is short: the service is local and the server is
// waiting (synchronously before a CoA, at worst).
var radcacheDeleteClient = &http.Client{Timeout: 3 * time.Second}

// connectorCacheRadcacheDelete removes every cached reply of a device:
// POST {connectorCacheURL}/radcache/delete {"mac": mac}, idempotent on the
// cache side (connector-cache 0.1.8+ takes this body; an older one answers
// 200 without deleting, since it reads Calling-Station-Id only).
func connectorCacheRadcacheDelete(mac string) (int, []byte, error) {
	body, _ := json.Marshal(map[string]string{"mac": mac})
	req, err := http.NewRequest(http.MethodPost, connectorCacheURL+"/radcache/delete", bytes.NewReader(body))
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	res, err := radcacheDeleteClient.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer res.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(res.Body, 4096))
	return res.StatusCode, raw, nil
}

// normalizeMac returns the MAC as aa:bb:cc:dd:ee:ff whatever the separators
// (":", "-", "." or none), false when it is not a MAC address.
func normalizeMac(mac string) (string, bool) {
	hex := strings.NewReplacer(":", "", "-", "", ".", "").Replace(strings.ToLower(strings.TrimSpace(mac)))
	if len(hex) != 12 {
		return "", false
	}
	for _, c := range hex {
		if (c < '0' || c > '9') && (c < 'a' || c > 'f') {
			return "", false
		}
	}
	var b strings.Builder
	for i := 0; i < 12; i += 2 {
		if i > 0 {
			b.WriteByte(':')
		}
		b.WriteString(hex[i : i+2])
	}
	return b.String(), true
}

type radiusCacheInvalidateFailure struct {
	Mac    string `json:"mac"`
	Status int    `json:"status,omitempty"`
	Error  string `json:"error,omitempty"`
}

// radiusCacheInvalidate deletes the cached replies of the given devices.
// 200 {"deleted": n, "failed": [...]} (deleted counts the devices the cache
// acknowledged, whether or not they had an entry); 400 on a bad body, no
// valid MAC or too many of them; 502 when the cache service answered none of
// them.
func radiusCacheInvalidate(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			Macs []string `json:"macs"`
		}
		if err := json.NewDecoder(io.LimitReader(r.Body, radiusCacheInvalidateMaxBody)).Decode(&req); err != nil {
			writeMessage(w, http.StatusBadRequest, "Invalid request body")
			return
		}
		if len(req.Macs) > radiusCacheInvalidateMaxMacs {
			writeMessage(w, http.StatusBadRequest, fmt.Sprintf("At most %d devices per request", radiusCacheInvalidateMaxMacs))
			return
		}
		macs := []string{}
		seen := map[string]bool{}
		for _, m := range req.Macs {
			mac, ok := normalizeMac(m)
			if !ok || seen[mac] {
				continue
			}
			seen[mac] = true
			macs = append(macs, mac)
		}
		if len(macs) == 0 {
			writeMessage(w, http.StatusBadRequest, "No valid MAC address in the request")
			return
		}

		deleted := 0
		unreachable := 0
		failed := []radiusCacheInvalidateFailure{}
		for _, mac := range macs {
			status, raw, err := connectorCacheRadcacheDelete(mac)
			switch {
			case err != nil:
				unreachable++
				failed = append(failed, radiusCacheInvalidateFailure{Mac: mac, Error: err.Error()})
				log.LoggerWContext(api.ctx).Warn(fmt.Sprintf("radius cache: unable to drop the cached replies of %s: %v", mac, err))
			case status >= 300:
				failed = append(failed, radiusCacheInvalidateFailure{Mac: mac, Status: status, Error: strings.TrimSpace(string(raw))})
				log.LoggerWContext(api.ctx).Warn(fmt.Sprintf("radius cache: the cache service refused to drop the cached replies of %s: %d %s", mac, status, strings.TrimSpace(string(raw))))
			default:
				deleted++
				log.LoggerWContext(api.ctx).Debug(fmt.Sprintf("radius cache: dropped the cached replies of %s", mac))
			}
		}
		log.LoggerWContext(api.ctx).Info(fmt.Sprintf("radius cache: dropped the cached replies of %d of %d device(s) on request of PacketFence", deleted, len(macs)))
		w.Header().Set("Content-Type", "application/json")
		if unreachable == len(macs) {
			w.WriteHeader(http.StatusBadGateway)
		} else {
			w.WriteHeader(http.StatusOK)
		}
		json.NewEncoder(w).Encode(map[string]interface{}{"deleted": deleted, "failed": failed})
	})
}
