package clientapi

import (
	"bytes"
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
)

// HA phase 4: warm the credential caches of the backup hosts.
//
// connector-cache keeps the offline material of a connector-remote in the
// SQLite file below: the "device" table (cached RADIUS replies, replayed in
// degraded mode) and the "credential" table (NT keys for PEAP inner auth
// through the local ntlm wrapper). Both are filled on the master only, since
// the cloud pushes credentials through the tunnel and replies are cached on
// post-proxy. A backup that takes over would otherwise start with an empty
// cache and answer degraded authentications from nothing.
//
// The backup pulls a snapshot from the master over the site LAN every
// haCacheSyncInterval: GET /api/v1/ha/cache-snapshot on the VIP, signed like
// the heartbeat, body encrypted with AES-256-GCM under a key derived from the
// connector secret (the snapshot carries NT hashes). The snapshot is taken
// with the SQLite online backup (consistent with the live WAL) and imported
// as a full mirror (INSERT OR REPLACE + delete of rows absent from the
// snapshot) into the backup's live database through the sqlite3 CLI, which
// the image ships; connector-cache keeps running throughout.

var (
	// cacheDBPath is the connector-cache SQLite database (bind-mounted).
	cacheDBPath = sharedutils.EnvOrDefault("PFCONNECTOR_CACHE_DB", "/usr/local/packetfence-connector-cache/pfcc.db")
	sqlite3Bin  = sharedutils.EnvOrDefault("PFCONNECTOR_SQLITE3", "sqlite3")
	// HACacheSyncInterval is how often a backup pulls the master's cache.
	HACacheSyncInterval = sharedutils.EnvOrDefaultDuration("PFCONNECTOR_HA_CACHE_SYNC_INTERVAL", time.Minute)
	// cacheTables are mirrored, in this order. Each has a primary key.
	cacheTables = []string{"device", "credential"}
	// haCacheMaxSnapshot bounds what a backup accepts from the master.
	haCacheMaxSnapshot int64 = 512 << 20
)

// HACacheKey derives the snapshot encryption key from the connector secret.
func HACacheKey(secret string) []byte {
	sum := sha256.Sum256([]byte("pfconnector-ha-cache:" + secret))
	return sum[:]
}

// cacheSnapshotSignature signs the request: there is no body, so the
// timestamp is what gets authenticated (bounded by haHeartbeatMaxSkew).
func cacheSnapshotSignature(key []byte, ts string) string {
	mac := hmac.New(sha256.New, key)
	mac.Write([]byte("cache-snapshot:" + ts))
	return hex.EncodeToString(mac.Sum(nil))
}

// SnapshotCacheDB returns a consistent copy of the connector-cache database
// (SQLite online backup through the sqlite3 CLI).
func SnapshotCacheDB(dbPath string) ([]byte, error) {
	if _, err := os.Stat(dbPath); err != nil {
		return nil, fmt.Errorf("cache database: %w", err)
	}
	tmp, err := os.CreateTemp(filepath.Dir(dbPath), ".pfcc-snapshot-*.db")
	if err != nil {
		return nil, err
	}
	tmpPath := tmp.Name()
	tmp.Close()
	defer os.Remove(tmpPath)
	// .backup needs a path without quotes; ours has none.
	cmd := exec.Command(sqlite3Bin, "-bail", dbPath, fmt.Sprintf(".backup %s", tmpPath))
	if out, err := cmd.CombinedOutput(); err != nil {
		return nil, fmt.Errorf("sqlite3 backup: %w: %s", err, strings.TrimSpace(string(out)))
	}
	return os.ReadFile(tmpPath)
}

// ImportCacheSnapshot mirrors the snapshot's cache tables into the live
// database and returns the number of rows now in the mirrored tables.
func ImportCacheSnapshot(dbPath string, snapshot []byte) (int, error) {
	if !bytes.HasPrefix(snapshot, []byte("SQLite format 3\x00")) {
		return 0, fmt.Errorf("snapshot is not a SQLite database")
	}
	tmp, err := os.CreateTemp(filepath.Dir(dbPath), ".pfcc-import-*.db")
	if err != nil {
		return 0, err
	}
	tmpPath := tmp.Name()
	if _, err := tmp.Write(snapshot); err != nil {
		tmp.Close()
		os.Remove(tmpPath)
		return 0, err
	}
	tmp.Close()
	defer os.Remove(tmpPath)

	// Only mirror tables that exist on both sides, so a schema difference
	// between versions degrades to a partial sync instead of an error.
	present := func(path string) (map[string]bool, error) {
		out, err := exec.Command(sqlite3Bin, path, "SELECT name FROM sqlite_master WHERE type='table'").Output()
		if err != nil {
			return nil, fmt.Errorf("sqlite3 tables of %s: %w", filepath.Base(path), err)
		}
		set := map[string]bool{}
		for _, n := range strings.Fields(string(out)) {
			set[n] = true
		}
		return set, nil
	}
	live, err := present(dbPath)
	if err != nil {
		return 0, err
	}
	src, err := present(tmpPath)
	if err != nil {
		return 0, err
	}

	var sqlb strings.Builder
	fmt.Fprintf(&sqlb, "ATTACH DATABASE '%s' AS src;\nPRAGMA busy_timeout = 5000;\nBEGIN IMMEDIATE;\n", tmpPath)
	pk := map[string]string{"device": "mac", "credential": "user"}
	mirrored := []string{}
	for _, t := range cacheTables {
		if !live[t] || !src[t] {
			continue
		}
		fmt.Fprintf(&sqlb, "DELETE FROM main.%s WHERE %s NOT IN (SELECT %s FROM src.%s);\n", t, pk[t], pk[t], t)
		fmt.Fprintf(&sqlb, "INSERT OR REPLACE INTO main.%s SELECT * FROM src.%s;\n", t, t)
		mirrored = append(mirrored, t)
	}
	sqlb.WriteString("COMMIT;\nDETACH DATABASE src;\n")
	counts := []string{}
	for _, t := range mirrored {
		counts = append(counts, fmt.Sprintf("(SELECT count(*) FROM main.%s)", t))
	}
	if len(counts) > 0 {
		fmt.Fprintf(&sqlb, "SELECT %s;\n", strings.Join(counts, " + "))
	}
	// -bail: the CLI otherwise continues after a failed statement and exits 0.
	cmd := exec.Command(sqlite3Bin, "-bail", dbPath)
	cmd.Stdin = strings.NewReader(sqlb.String())
	out, err := cmd.CombinedOutput()
	if err != nil {
		return 0, fmt.Errorf("sqlite3 import: %w: %s", err, strings.TrimSpace(string(out)))
	}
	// The count is the last output line (PRAGMA busy_timeout echoes its value).
	lines := strings.Fields(strings.TrimSpace(string(out)))
	rows := 0
	if len(lines) > 0 {
		rows, err = strconv.Atoi(lines[len(lines)-1])
		if err != nil {
			return 0, fmt.Errorf("sqlite3 import: unexpected output %q", strings.TrimSpace(string(out)))
		}
	}
	return rows, nil
}

// encryptSnapshot seals data with AES-256-GCM; the nonce is prepended.
func encryptSnapshot(key, data []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}
	return append(nonce, gcm.Seal(nil, nonce, data, nil)...), nil
}

// decryptSnapshot is the inverse of encryptSnapshot.
func decryptSnapshot(key, sealed []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	if len(sealed) < gcm.NonceSize() {
		return nil, fmt.Errorf("snapshot too short")
	}
	return gcm.Open(nil, sealed[:gcm.NonceSize()], sealed[gcm.NonceSize():], nil)
}

// haCacheSnapshot serves GET /api/v1/ha/cache-snapshot?ts=<unix> to the
// backups (not localhost-only, HMAC-signed timestamp, encrypted body). Only
// the master answers: a backup's cache is itself a mirror.
func haCacheSnapshot(api *API) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		haStatusMu.RLock()
		enabled := haStatus != nil && haStatus.State == "master"
		key := haKey
		secretKey := haCacheKeyValue
		haStatusMu.RUnlock()
		if !enabled || len(key) == 0 || len(secretKey) == 0 {
			http.NotFound(w, r)
			return
		}
		ts := r.URL.Query().Get("ts")
		want := cacheSnapshotSignature(key, ts)
		got := r.Header.Get(haSignatureHeader)
		if ts == "" || len(got) != len(want) || !hmac.Equal([]byte(got), []byte(want)) {
			log.LoggerWContext(api.ctx).Warn(fmt.Sprintf("HA cache snapshot request from %s refused: bad signature", r.RemoteAddr))
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
		data, err := SnapshotCacheDB(cacheDBPath)
		if err != nil {
			log.LoggerWContext(api.ctx).Error(fmt.Sprintf("HA cache snapshot: %s", err))
			http.Error(w, "snapshot unavailable", http.StatusServiceUnavailable)
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

var haCacheKeyValue []byte

// setHACacheKey is called with SetHASecret.
func setHACacheKey(secret string) {
	haCacheKeyValue = HACacheKey(secret)
}

var haCacheClient = &http.Client{Timeout: 60 * time.Second}

// FetchCacheSnapshot downloads and decrypts the master's cache snapshot.
func FetchCacheSnapshot(ctx context.Context, vip, secret string) ([]byte, error) {
	ts := strconv.FormatInt(time.Now().Unix(), 10)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fmt.Sprintf("http://%s:8081/api/v1/ha/cache-snapshot?ts=%s", vip, ts), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set(haSignatureHeader, cacheSnapshotSignature(HAKey(secret), ts))
	res, err := haCacheClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		io.Copy(io.Discard, res.Body)
		return nil, fmt.Errorf("HTTP %d", res.StatusCode)
	}
	sealed, err := io.ReadAll(io.LimitReader(res.Body, haCacheMaxSnapshot+1))
	if err != nil {
		return nil, err
	}
	if int64(len(sealed)) > haCacheMaxSnapshot {
		return nil, fmt.Errorf("snapshot larger than %d bytes", haCacheMaxSnapshot)
	}
	return decryptSnapshot(HACacheKey(secret), sealed)
}

// CacheSyncState is what a backup reports about its cache mirror (in its
// heartbeat, so the master and the admin UI can show it).
type CacheSyncState struct {
	SyncedAt *time.Time `json:"cache_synced_at,omitempty"`
	Error    string     `json:"cache_sync_error,omitempty"`
	Rows     int        `json:"cache_rows"`
}

var (
	cacheSyncMu    sync.RWMutex
	cacheSyncState CacheSyncState
)

// SyncCacheFromMaster pulls the master's snapshot and mirrors it locally,
// recording the outcome for the heartbeat.
func SyncCacheFromMaster(ctx context.Context, vip, secret string) error {
	snapshot, err := FetchCacheSnapshot(ctx, vip, secret)
	var rows int
	if err == nil {
		rows, err = ImportCacheSnapshot(cacheDBPath, snapshot)
	}
	cacheSyncMu.Lock()
	defer cacheSyncMu.Unlock()
	if err != nil {
		cacheSyncState.Error = err.Error()
		return err
	}
	now := time.Now()
	cacheSyncState = CacheSyncState{SyncedAt: &now, Rows: rows}
	return nil
}

// cacheSyncSnapshot returns the current cache sync state.
func cacheSyncSnapshot() CacheSyncState {
	cacheSyncMu.RLock()
	defer cacheSyncMu.RUnlock()
	return cacheSyncState
}
