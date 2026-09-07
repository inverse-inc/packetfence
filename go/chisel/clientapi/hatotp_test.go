package clientapi

import (
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

// A standby adopts the master's seed: the endpoint refuses loopback callers
// and bad signatures, serves the seed encrypted to a LAN peer, and the sync
// rewrites the standby's seed file and reloads the second factor.
func TestHATOTPSeedSync(t *testing.T) {
	dir := t.TempDir()
	secret := "s3cret"

	master := &API{ctx: context.Background(), terminalTOTPRequired: true}
	masterSeed, err := newTerminalTOTPIn(filepath.Join(dir, "master"), "conn")
	if err != nil {
		t.Fatal(err)
	}
	master.terminalTOTP = masterSeed

	haStatusMu.Lock()
	haStatus = &HAStatus{Enabled: true, State: "master"}
	haStatusMu.Unlock()
	SetHASecret(secret)
	t.Cleanup(ClearHAState)

	handler := haTOTPSeed(master)
	ts := strconv.FormatInt(time.Now().Unix(), 10)

	// Loopback (tunnel traffic) never gets the seed, signature or not.
	req := httptest.NewRequest(http.MethodGet, "/api/v1/ha/totp-seed?ts="+ts, nil)
	req.RemoteAddr = "127.0.0.1:4242"
	req.Header.Set(haSignatureHeader, totpSeedSignature(HAKey(secret), ts))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("loopback caller: got %d, want 404", rec.Code)
	}

	// A LAN peer with a bad signature is refused.
	req = httptest.NewRequest(http.MethodGet, "/api/v1/ha/totp-seed?ts="+ts, nil)
	req.RemoteAddr = "192.0.2.10:4242"
	req.Header.Set(haSignatureHeader, totpSeedSignature(HAKey("other"), ts))
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("bad signature: got %d, want 403", rec.Code)
	}

	// The standby, reached through a test server standing for the VIP.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		r.RemoteAddr = "192.0.2.10:4242" // the test client connects over loopback
		handler.ServeHTTP(w, r)
	}))
	defer srv.Close()
	vip, port, _ := net.SplitHostPort(strings.TrimPrefix(srv.URL, "http://"))
	savedPort := haTOTPSeedPort
	haTOTPSeedPort = port
	t.Cleanup(func() { haTOTPSeedPort = savedPort })

	standbyFile := filepath.Join(dir, "standby")
	t.Setenv("PFCONNECTOR_TERMINAL_TOTP_FILE", standbyFile)
	standby := &API{ctx: context.Background(), terminalTOTPRequired: true}
	standby.terminalTOTP, err = newTerminalTOTP(context.Background(), "conn")
	if err != nil {
		t.Fatal(err)
	}
	if standby.terminalTOTPURL() == master.terminalTOTPURL() {
		t.Fatal("test setup: the two hosts should start with different seeds")
	}

	changed, err := standby.SyncTOTPSeedFromMaster(context.Background(), vip, secret)
	if err != nil {
		t.Fatalf("sync: %v", err)
	}
	if !changed {
		t.Fatal("first sync should adopt the master's seed")
	}
	if standby.terminalTOTPURL() != master.terminalTOTPURL() {
		t.Fatal("standby did not reload the master's seed")
	}
	raw, _ := os.ReadFile(standbyFile)
	if strings.TrimSpace(string(raw)) != master.terminalTOTPURL() {
		t.Fatalf("seed file not rewritten: %q", raw)
	}
	if !totpSeedInSync() {
		t.Fatal("sync state should report in sync")
	}

	// Already in sync: nothing changes.
	changed, err = standby.SyncTOTPSeedFromMaster(context.Background(), vip, secret)
	if err != nil || changed {
		t.Fatalf("second sync: changed=%v err=%v", changed, err)
	}

	// A master without a seed (second factor disabled) leaves ours alone.
	master.terminalTOTPRequired = false
	if _, err := standby.SyncTOTPSeedFromMaster(context.Background(), vip, secret); err != ErrTOTPSeedUnavailable {
		t.Fatalf("master without seed: err=%v, want ErrTOTPSeedUnavailable", err)
	}
	if standby.terminalTOTPURL() == "" {
		t.Fatal("standby lost its seed")
	}
}

// newTerminalTOTPIn generates a seed persisted in the given file.
func newTerminalTOTPIn(path, connectorID string) (*terminalTOTP, error) {
	os.Setenv("PFCONNECTOR_TERMINAL_TOTP_FILE", path)
	defer os.Unsetenv("PFCONNECTOR_TERMINAL_TOTP_FILE")
	return newTerminalTOTP(context.Background(), connectorID)
}
