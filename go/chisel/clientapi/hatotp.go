package clientapi

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/pquerna/otp"
)

// HA: one terminal TOTP seed for the whole group.
//
// The seed gating remote terminal activation (terminal_totp.go) is generated
// per host, so a group of connector-remotes would need one authenticator
// enrolment per host and the admin would have to know which one is active.
// Instead the active host is the source of truth: every standby pulls its
// seed over the site LAN (GET /api/v1/ha/totp-seed on the VIP, signed like the
// cache snapshot, body encrypted under a key derived from the connector
// secret), writes it to its own seed file when it differs and reloads it
// live. A host joining an existing group thus adopts the seed of the first
// one, and keeps it when it becomes active itself.
//
// The seed must not be fetchable from central through the tunnel, which
// reaches this API as loopback traffic (see terminal_totp.go): the endpoint
// only answers a peer on the LAN, never a loopback or local source.

// HATOTPKey derives the seed encryption key from the connector secret.
func HATOTPKey(secret string) []byte {
	sum := sha256.Sum256([]byte("pfconnector-ha-totp:" + secret))
	return sum[:]
}

// totpSeedSignature signs the request; distinct from the snapshot signature
// so one cannot be replayed as the other.
func totpSeedSignature(key []byte, ts string) string {
	mac := hmac.New(sha256.New, key)
	mac.Write([]byte("totp-seed:" + ts))
	return hex.EncodeToString(mac.Sum(nil))
}

var haTOTPKeyValue []byte

// setHATOTPKey is called with SetHASecret.
func setHATOTPKey(secret string) {
	haTOTPKeyValue = HATOTPKey(secret)
}

// haTOTPSeed serves GET /api/v1/ha/totp-seed?ts=<unix> to the standby hosts.
// Only the master answers, only to a LAN peer, and only when it has a seed.
func haTOTPSeed(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		haStatusMu.RLock()
		enabled := haStatus != nil && haStatus.State == "master"
		key := haKey
		secretKey := haTOTPKeyValue
		haStatusMu.RUnlock()
		if !enabled || len(key) == 0 || len(secretKey) == 0 {
			http.NotFound(w, r)
			return
		}
		addr := r.RemoteAddr
		if i := strings.LastIndex(addr, ":"); i > 0 {
			addr = addr[:i]
		}
		ip := net.ParseIP(strings.Trim(addr, "[]"))
		if ip == nil || ip.IsLoopback() || isLocalAddress(addr) {
			// Tunnel traffic (central) and this host itself: not a peer.
			http.NotFound(w, r)
			return
		}
		ts := r.URL.Query().Get("ts")
		want := totpSeedSignature(key, ts)
		got := r.Header.Get(haSignatureHeader)
		if ts == "" || len(got) != len(want) || !hmac.Equal([]byte(got), []byte(want)) {
			log.LoggerWContext(api.ctx).Warn(fmt.Sprintf("HA TOTP seed request from %s refused: bad signature", r.RemoteAddr))
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
		seed := api.terminalTOTPURL()
		if seed == "" {
			http.NotFound(w, r)
			return
		}
		sealed, err := encryptSnapshot(secretKey, []byte(seed))
		if err != nil {
			http.Error(w, "encryption failed", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/octet-stream")
		w.Header().Set("Content-Length", strconv.Itoa(len(sealed)))
		w.Write(sealed)
	})
}

// terminalTOTPURL returns the otpauth URL of the loaded seed, "" when the
// second factor is disabled or not initialized.
func (api *API) terminalTOTPURL() string {
	api.terminalTOTPMu.RLock()
	defer api.terminalTOTPMu.RUnlock()
	if !api.terminalTOTPRequired || api.terminalTOTP == nil {
		return ""
	}
	return api.terminalTOTP.key.URL()
}

// currentTerminalTOTP returns the loaded second factor (nil when none).
func (api *API) currentTerminalTOTP() *terminalTOTP {
	api.terminalTOTPMu.RLock()
	defer api.terminalTOTPMu.RUnlock()
	return api.terminalTOTP
}

var haTOTPClient = &http.Client{Timeout: 5 * time.Second}

// haTOTPSeedPort is the side-car API port on the VIP (a variable for tests).
var haTOTPSeedPort = "8081"

// FetchTOTPSeed downloads and decrypts the master's seed (otpauth URL).
func FetchTOTPSeed(ctx context.Context, vip, secret string) (string, error) {
	ts := strconv.FormatInt(time.Now().Unix(), 10)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fmt.Sprintf("http://%s/api/v1/ha/totp-seed?ts=%s", net.JoinHostPort(vip, haTOTPSeedPort), ts), nil)
	if err != nil {
		return "", err
	}
	req.Header.Set(haSignatureHeader, totpSeedSignature(HAKey(secret), ts))
	res, err := haTOTPClient.Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		io.Copy(io.Discard, res.Body)
		return "", fmt.Errorf("HTTP %d", res.StatusCode)
	}
	sealed, err := io.ReadAll(io.LimitReader(res.Body, 64<<10))
	if err != nil {
		return "", err
	}
	plain, err := decryptSnapshot(HATOTPKey(secret), sealed)
	if err != nil {
		return "", err
	}
	seed := strings.TrimSpace(string(plain))
	if _, err := otp.NewKeyFromURL(seed); err != nil {
		return "", fmt.Errorf("invalid seed from the master: %w", err)
	}
	return seed, nil
}

var (
	totpSyncMu     sync.RWMutex
	totpSeedSynced bool
)

// totpSeedInSync reports whether this host's seed matched the master's at
// the last sync (false until the first successful sync).
func totpSeedInSync() bool {
	totpSyncMu.RLock()
	defer totpSyncMu.RUnlock()
	return totpSeedSynced
}

// ErrTOTPSeedUnavailable: the master has no seed to share (second factor
// disabled there, or not initialized). This host keeps its own.
var ErrTOTPSeedUnavailable = fmt.Errorf("the active host has no TOTP seed")

// SyncTOTPSeedFromMaster pulls the master's seed and adopts it when it differs
// from the local one: the seed file is rewritten and the second factor
// reloaded, so the authenticator enrolled on the master opens the terminal
// here as soon as this host becomes active. Returns whether the seed changed.
func (api *API) SyncTOTPSeedFromMaster(ctx context.Context, vip, secret string) (bool, error) {
	seed, err := FetchTOTPSeed(ctx, vip, secret)
	if err != nil {
		totpSyncMu.Lock()
		totpSeedSynced = false
		totpSyncMu.Unlock()
		if strings.HasSuffix(err.Error(), "HTTP 404") {
			return false, ErrTOTPSeedUnavailable
		}
		return false, err
	}
	changed := false
	if api.terminalTOTPURL() != seed {
		key, err := otp.NewKeyFromURL(seed)
		if err != nil {
			return false, err
		}
		path := terminalTOTPFile()
		if err := os.WriteFile(path, []byte(seed+"\n"), 0600); err != nil {
			return false, fmt.Errorf("persisting the TOTP seed to %s: %w", path, err)
		}
		api.terminalTOTPMu.Lock()
		api.terminalTOTP = &terminalTOTP{key: key}
		api.terminalTOTPMu.Unlock()
		changed = true
	}
	totpSyncMu.Lock()
	totpSeedSynced = true
	totpSyncMu.Unlock()
	return changed, nil
}
