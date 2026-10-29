package clientapi

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestHostServiceAllowed(t *testing.T) {
	allowed := []string{
		"packetfence-ntlm-auth-api-remote.service",
		"packetfence-ntlm-auth-join-remote.service",
		"packetfence-ntlm-auth-api-domain-remote@EXAMPLE.service",
		"packetfence-ntlm-auth-api-domain-remote@corp.example.org.service",
	}
	for _, name := range allowed {
		if !hostServiceAllowed(name) {
			t.Errorf("%s must be allowed", name)
		}
	}
	refused := []string{
		"",
		"packetfence-pfconnector-remote-combined.service",
		"docker.service",
		"packetfence-ntlm-auth-api-remote",
		"packetfence-ntlm-auth-api-domain-remote@.service",
		"packetfence-ntlm-auth-api-domain-remote@a b.service",
		"packetfence-ntlm-auth-api-domain-remote@../x.service",
		"packetfence-ntlm-auth-api-domain-remote@x.service; reboot",
		"packetfence-ntlm-auth-api-domain-remote@" + strings.Repeat("a", 65) + ".service",
	}
	for _, name := range refused {
		if hostServiceAllowed(name) {
			t.Errorf("%q must be refused", name)
		}
	}
}

// withServicesFiles points the trigger and state files at a temp dir.
func withServicesFiles(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	oldTrigger, oldState, oldLast := servicesTriggerFile, servicesStateFile, servicesRefreshLast
	servicesTriggerFile = filepath.Join(dir, "services_requested")
	servicesStateFile = filepath.Join(dir, "services_state")
	servicesRefreshLast = time.Time{}
	t.Cleanup(func() {
		servicesTriggerFile, servicesStateFile, servicesRefreshLast = oldTrigger, oldState, oldLast
	})
	return dir
}

func TestHostServicesReadsState(t *testing.T) {
	withServicesFiles(t)
	updated := time.Now().UTC().Format(time.RFC3339)
	os.WriteFile(servicesStateFile, []byte(`{"updated":"`+updated+`","last_action":{"action":"stop","unit":"packetfence-ntlm-auth-api-remote.service","at":"`+updated+`","result":"ok","message":""},"services":[{"name":"packetfence-ntlm-auth-api-remote.service","installed":true,"active_state":"inactive","sub_state":"dead","unit_file_state":"enabled","restarts":0,"since":"","description":"PacketFence NTLM auth Backend API Controller Remote"},{"name":"packetfence-ntlm-auth-api-domain-remote@EXAMPLE.service","installed":true,"active_state":"activating","sub_state":"auto-restart","restarts":448}]}`), 0o644)
	got := hostServices()
	if !got.Available || got.Stale {
		t.Fatalf("fresh state must be available and not stale: %+v", got)
	}
	if len(got.Services) != 2 || got.Services[1].Restarts != 448 || got.Services[0].ActiveState != "inactive" {
		t.Fatalf("services: %+v", got.Services)
	}
	if got.LastAction == nil || got.LastAction.Action != "stop" || got.LastAction.Result != "ok" {
		t.Fatalf("last action: %+v", got.LastAction)
	}
	if _, err := os.Stat(servicesTriggerFile); err == nil {
		t.Fatalf("a fresh state must not request a refresh")
	}
}

func TestHostServicesRequestsRefreshWhenMissingOrStale(t *testing.T) {
	withServicesFiles(t)
	got := hostServices()
	if got.Available || got.Services == nil {
		t.Fatalf("missing state: %+v", got)
	}
	data, err := os.ReadFile(servicesTriggerFile)
	if err != nil || string(data) != "status\n" {
		t.Fatalf("a missing state must request a status refresh, got %q (%v)", data, err)
	}
	os.Remove(servicesTriggerFile)

	// stale state: reported, flagged, refresh requested (once the minimum
	// interval between requests has passed)
	servicesRefreshLast = time.Time{}
	old := time.Now().Add(-2 * servicesStateMaxAge).UTC().Format(time.RFC3339)
	os.WriteFile(servicesStateFile, []byte(`{"updated":"`+old+`","services":[{"name":"packetfence-ntlm-auth-join-remote.service","installed":true,"active_state":"active","sub_state":"running"}]}`), 0o644)
	got = hostServices()
	if !got.Available || !got.Stale || len(got.Services) != 1 {
		t.Fatalf("stale state: %+v", got)
	}
	if data, err := os.ReadFile(servicesTriggerFile); err != nil || string(data) != "status\n" {
		t.Fatalf("a stale state must request a status refresh, got %q (%v)", data, err)
	}
}

func TestRefreshNeverReplacesAPendingAction(t *testing.T) {
	withServicesFiles(t)
	if err := writeHostServiceTrigger("restart", "packetfence-ntlm-auth-api-remote.service"); err != nil {
		t.Fatal(err)
	}
	hostServices() // no state: wants a refresh
	data, _ := os.ReadFile(servicesTriggerFile)
	if string(data) != "restart packetfence-ntlm-auth-api-remote.service\n" {
		t.Fatalf("the pending action was replaced: %q", data)
	}
	if entries, _ := os.ReadDir(filepath.Dir(servicesTriggerFile)); len(entries) != 1 {
		t.Fatalf("temporary files left behind: %v", entries)
	}
}

func TestHostServiceActionHandler(t *testing.T) {
	withServicesFiles(t)
	api := &API{ctx: context.Background()}

	do := func(action, body string) *httptest.ResponseRecorder {
		rec := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodPost, "/api/v1/service/"+action, bytes.NewBufferString(body))
		hostServiceAction(api, action).ServeHTTP(rec, req)
		return rec
	}

	rec := do("stop", `{"service":"packetfence-ntlm-auth-api-domain-remote@EXAMPLE.service"}`)
	if rec.Code != http.StatusAccepted {
		t.Fatalf("stop: %d %s", rec.Code, rec.Body.String())
	}
	var reply map[string]string
	json.Unmarshal(rec.Body.Bytes(), &reply)
	if reply["action"] != "stop" || reply["service"] != "packetfence-ntlm-auth-api-domain-remote@EXAMPLE.service" {
		t.Fatalf("reply: %v", reply)
	}
	data, err := os.ReadFile(servicesTriggerFile)
	if err != nil || string(data) != "stop packetfence-ntlm-auth-api-domain-remote@EXAMPLE.service\n" {
		t.Fatalf("trigger: %q (%v)", data, err)
	}

	if rec := do("stop", `{"service":"docker.service"}`); rec.Code != http.StatusForbidden {
		t.Fatalf("a unit outside the allowlist must be refused: %d", rec.Code)
	}
	if rec := do("enable", `{"service":"packetfence-ntlm-auth-api-remote.service"}`); rec.Code != http.StatusBadRequest {
		t.Fatalf("an unknown action must be refused: %d", rec.Code)
	}
	if rec := do("start", `{}`); rec.Code != http.StatusBadRequest {
		t.Fatalf("a missing name must be refused: %d", rec.Code)
	}
	if rec := do("start", `not json`); rec.Code != http.StatusBadRequest {
		t.Fatalf("an invalid body must be refused: %d", rec.Code)
	}
}
