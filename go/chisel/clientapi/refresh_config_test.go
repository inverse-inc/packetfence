package clientapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestRefreshConfigRunnerCoalesces(t *testing.T) {
	var runs int32
	r := newRefreshConfigRunner(func() {
		atomic.AddInt32(&runs, 1)
		time.Sleep(50 * time.Millisecond)
	})
	if !r.Trigger() {
		t.Fatalf("the first trigger must start a run")
	}
	time.Sleep(10 * time.Millisecond)
	// three requests during the run: exactly one more run after it
	for i := 0; i < 3; i++ {
		if r.Trigger() {
			t.Fatalf("a trigger during a run must queue, not start")
		}
	}
	time.Sleep(200 * time.Millisecond)
	if got := atomic.LoadInt32(&runs); got != 2 {
		t.Fatalf("expected 2 runs (one, plus one for the requests received meanwhile), got %d", got)
	}
	if !r.Trigger() {
		t.Fatalf("after the runs completed a trigger must start again")
	}
	time.Sleep(100 * time.Millisecond)
	if got := atomic.LoadInt32(&runs); got != 3 {
		t.Fatalf("expected 3 runs, got %d", got)
	}
}

func TestRunRefreshConfigScript(t *testing.T) {
	dir := t.TempDir()
	script := filepath.Join(dir, "refresh.sh")
	os.WriteFile(script, []byte("#!/bin/sh\necho \"2026/10/29 12:00:00 ha-refresh-config: RADIUS configuration changed, restarting radiusd-auth\"\necho \"plain line\"\necho \"ARG=$1 API=$PFCONNECTOR_API\"\nexit 3\n"), 0o755)
	saved := RefreshConfigScript
	RefreshConfigScript = script
	defer func() { RefreshConfigScript = saved }()

	lines, err := RunRefreshConfigScript(context.Background(), []string{"PFCONNECTOR_API=http://127.0.0.1:1"}, "--start")
	if err == nil {
		t.Fatalf("the script's exit code must be reported")
	}
	want := []string{"ha-refresh-config: RADIUS configuration changed, restarting radiusd-auth", "plain line", "ARG=--start API=http://127.0.0.1:1"}
	if strings.Join(lines, "|") != strings.Join(want, "|") {
		t.Fatalf("lines: %q", lines)
	}
}

func TestSystemRefreshConfigHandler(t *testing.T) {
	dir := t.TempDir()
	marker := filepath.Join(dir, "runs")
	script := filepath.Join(dir, "refresh.sh")
	os.WriteFile(script, []byte("#!/bin/sh\necho run >> "+marker+"\n"), 0o755)
	saved := RefreshConfigScript
	RefreshConfigScript = script
	defer func() { RefreshConfigScript = saved }()
	api := &API{ctx: context.Background()}

	rec := httptest.NewRecorder()
	systemRefreshConfig(api).ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/api/v1/system/refresh-config", nil))
	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d %s", rec.Code, rec.Body.String())
	}
	deadline := time.Now().Add(2 * time.Second)
	for {
		if data, err := os.ReadFile(marker); err == nil && strings.Count(string(data), "run") == 1 {
			break
		}
		if time.Now().After(deadline) {
			t.Fatalf("the script did not run")
		}
		time.Sleep(10 * time.Millisecond)
	}

	RefreshConfigScript = filepath.Join(dir, "missing.sh")
	rec = httptest.NewRecorder()
	systemRefreshConfig(api).ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/api/v1/system/refresh-config", nil))
	if rec.Code != http.StatusNotImplemented {
		t.Fatalf("without the script: expected 501, got %d", rec.Code)
	}
}
