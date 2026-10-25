package clientapi

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/chisel/share/connauth"
)

// Configuration relay for the HA backups (docs/design/pfconnector-remote-ha.md,
// 3.2.2). A backup has no tunnel, so it cannot fetch the connector
// configuration from the pfconnector server: without help it only learns a
// change (a new site VLAN, a rotated RADIUS certificate, a new switch) when it
// takes the VIP, and a host that never held the VIP has no configuration at
// all. The master therefore answers a fixed set of the tunnel API calls on
// behalf of its backups: GET /api/v1/ha/config-relay?name=<name>&ts=<unix> on
// the VIP, signed like the heartbeat, body encrypted like the cache snapshot
// (it carries the RADIUS secret and private key). On the backup,
// ServeConfigRelay exposes the same calls on a loopback port so that the
// container's sync scripts run unchanged against it (PFCONNECTOR_API).

// haConfigRelayEndpoint is one tunnel API call the master relays. IDParam
// names the query parameter carrying the connector id, when the call takes
// one; the master always sends its own (the group shares the connector).
type haConfigRelayEndpoint struct {
	Path    string
	IDParam string
}

var haConfigRelayEndpoints = map[string]haConfigRelayEndpoint{
	"radius-secret":                        {Path: "/api/v1/pfconnector/radius-secret"},
	"remote-radius-conf":                   {Path: "/api/v1/pfconnector/remote-radius-conf"},
	"remote-radius-nas":                    {Path: "/api/v1/pfconnector/remote-radius-nas", IDParam: "CONNECTOR_ID"},
	"remote-fingerbank-collector-nba-conf": {Path: "/api/v1/pfconnector/remote-fingerbank-collector-nba-conf"},
	"remote-fingerbank-collector-env":      {Path: "/api/v1/pfconnector/remote-fingerbank-collector-env", IDParam: "CONNECTOR_ID"},
	"site-network":                         {Path: "/api/v1/pfconnector/site-network", IDParam: "connector-id"},
}

var (
	// haTunnelAPIBase is the tunnel-local pfconnector server API on the master.
	haTunnelAPIBase = "http://127.0.0.1:22226"
	// haConfigRelayMax bounds a relayed answer.
	haConfigRelayMax int64 = 16 << 20
	haConfigClient         = &http.Client{Timeout: 20 * time.Second}
	// haConnectorSecret signs the relayed calls to the server (connauth).
	haConnectorSecret string
)

// configRelaySignature signs a relay request (name and timestamp; no body).
func configRelaySignature(key []byte, name, ts string) string {
	mac := hmac.New(sha256.New, key)
	mac.Write([]byte("config-relay:" + name + ":" + ts))
	return hex.EncodeToString(mac.Sum(nil))
}

// haConfigRelay serves GET /api/v1/ha/config-relay to the backups (not
// localhost-only, HMAC-signed name and timestamp, encrypted body). Only the
// master answers: it is the host with the tunnel.
func haConfigRelay(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		haStatusMu.RLock()
		enabled := haStatus != nil && haStatus.State == "master"
		key := haKey
		secretKey := haCacheKeyValue
		connectorSecret := haConnectorSecret
		haStatusMu.RUnlock()
		if !enabled || len(key) == 0 || len(secretKey) == 0 || !peerRequest(r) {
			http.NotFound(w, r)
			return
		}
		name := r.URL.Query().Get("name")
		ts := r.URL.Query().Get("ts")
		want := configRelaySignature(key, name, ts)
		got := r.Header.Get(haSignatureHeader)
		if ts == "" || len(got) != len(want) || !hmac.Equal([]byte(got), []byte(want)) {
			log.LoggerWContext(api.ctx).Warn(fmt.Sprintf("HA config relay request from %s refused: bad signature", r.RemoteAddr))
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		unix, err := strconv.ParseInt(ts, 10, 64)
		if err != nil {
			http.Error(w, "invalid timestamp", http.StatusBadRequest)
			return
		}
		if skew := time.Since(time.Unix(unix, 0)); skew > haHeartbeatMaxSkew || skew < -haHeartbeatMaxSkew {
			http.Error(w, "stale request", http.StatusForbidden)
			return
		}
		endpoint, ok := haConfigRelayEndpoints[name]
		if !ok {
			http.Error(w, "unknown configuration", http.StatusNotFound)
			return
		}
		data, err := relayTunnelGet(r.Context(), endpoint, api.ConnectorId, connectorSecret)
		if err != nil {
			log.LoggerWContext(api.ctx).Warn(fmt.Sprintf("HA config relay of %s for %s failed: %s", name, r.RemoteAddr, err))
			http.Error(w, "upstream unavailable", http.StatusBadGateway)
			return
		}
		sealed, err := encryptSnapshot(secretKey, data)
		if err != nil {
			http.Error(w, "encryption failed", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/octet-stream")
		w.Header().Set("Content-Length", strconv.Itoa(len(sealed)))
		w.Write(sealed)
	})
}

// relayTunnelGet performs one relayed call on the master's tunnel API.
func relayTunnelGet(ctx context.Context, endpoint haConfigRelayEndpoint, connectorID, connectorSecret string) ([]byte, error) {
	target := haTunnelAPIBase + endpoint.Path
	if endpoint.IDParam != "" {
		target += "?" + url.Values{endpoint.IDParam: {connectorID}}.Encode()
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, target, nil)
	if err != nil {
		return nil, err
	}
	if connectorSecret != "" {
		req.Header.Set(connauth.Header, connauth.Sign(connectorID, connectorSecret, time.Now()))
	}
	res, err := haConfigClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		io.Copy(io.Discard, res.Body)
		return nil, fmt.Errorf("server answered HTTP %d", res.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(res.Body, haConfigRelayMax+1))
	if err != nil {
		return nil, err
	}
	if int64(len(data)) > haConfigRelayMax {
		return nil, fmt.Errorf("answer larger than %d bytes", haConfigRelayMax)
	}
	return data, nil
}

// FetchConfigFromMaster gets one relayed configuration call from the master.
func FetchConfigFromMaster(ctx context.Context, vip, secret, name string) ([]byte, error) {
	if _, ok := haConfigRelayEndpoints[name]; !ok {
		return nil, fmt.Errorf("unknown configuration %q", name)
	}
	ts := strconv.FormatInt(time.Now().Unix(), 10)
	query := url.Values{"name": {name}, "ts": {ts}}.Encode()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fmt.Sprintf("http://%s/api/v1/ha/config-relay?%s", net.JoinHostPort(vip, "8081"), query), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set(haSignatureHeader, configRelaySignature(HAKey(secret), name, ts))
	res, err := haConfigClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		io.Copy(io.Discard, res.Body)
		return nil, fmt.Errorf("HTTP %d", res.StatusCode)
	}
	sealed, err := io.ReadAll(io.LimitReader(res.Body, haConfigRelayMax+1024))
	if err != nil {
		return nil, err
	}
	return decryptSnapshot(HACacheKey(secret), sealed)
}

// ServeConfigRelay answers GET /api/v1/pfconnector/<name> on addr (loopback)
// from the master until ctx is done, for the sync scripts run on a backup
// with PFCONNECTOR_API pointing here. The query string is ignored: the
// master adds its connector id itself.
func ServeConfigRelay(ctx context.Context, addr, vip, secret string) error {
	if host, _, err := net.SplitHostPort(addr); err != nil || !net.ParseIP(host).IsLoopback() {
		return fmt.Errorf("the HA config relay only listens on a loopback address, not %q", addr)
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/api/v1/pfconnector/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		name := strings.TrimPrefix(r.URL.Path, "/api/v1/pfconnector/")
		if _, ok := haConfigRelayEndpoints[name]; !ok {
			http.NotFound(w, r)
			return
		}
		data, err := FetchConfigFromMaster(r.Context(), vip, secret, name)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		w.Write(data)
	})
	srv := &http.Server{Addr: addr, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	go func() {
		<-ctx.Done()
		srv.Close()
	}()
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}
