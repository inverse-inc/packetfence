package clientapi

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// withFakeS6 replaces s6-svstat and s6-svc with scripts: s6-svstat prints the
// status line of the service named by its last argument from the given map
// (exit 1 for the others, like the real tool when the service is not
// supervised); s6-svc records its arguments in svcLog.
func withFakeS6(t *testing.T, status map[string]string) (svcLog string) {
	t.Helper()
	dir := t.TempDir()
	oldDir, oldSvstat, oldSvc := s6ServiceDir, s6SvstatBinary, s6SvcCommand
	s6ServiceDir = filepath.Join(dir, "service")
	for name := range status {
		if err := os.MkdirAll(filepath.Join(s6ServiceDir, name), 0755); err != nil {
			t.Fatal(err)
		}
	}
	var svstat strings.Builder
	svstat.WriteString("#!/bin/sh\nfor last; do :; done\ncase \"$(basename \"$last\")\" in\n")
	for name, line := range status {
		// -o up (the restart handler) only wants the first field
		fields := strings.Fields(line)
		fmt.Fprintf(&svstat, "%s) if [ \"$2\" = up ]; then echo %s; else echo '%s'; fi; exit 0;;\n", name, fields[0], line)
	}
	svstat.WriteString("*) echo \"s6-svstat: fatal: unable to read status for $last: s6-supervise not running\" >&2; exit 1;;\nesac\n")
	s6SvstatBinary = filepath.Join(dir, "s6-svstat")
	if err := os.WriteFile(s6SvstatBinary, []byte(svstat.String()), 0755); err != nil {
		t.Fatal(err)
	}
	svcLog = filepath.Join(dir, "svc.log")
	s6SvcCommand = filepath.Join(dir, "s6-svc")
	if err := os.WriteFile(s6SvcCommand, []byte("#!/bin/sh\necho \"$@\" >> "+svcLog+"\n"), 0755); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { s6ServiceDir, s6SvstatBinary, s6SvcCommand = oldDir, oldSvstat, oldSvc })
	return svcLog
}

func TestContainerServiceAllowed(t *testing.T) {
	for _, name := range []string{"radiusd-auth", "connector-cache", "fingerbank-collector"} {
		if !containerServiceAllowed(name) {
			t.Errorf("%s must be allowed", name)
		}
	}
	for _, name := range []string{"", "pfconnector-client", "keepalived", "rsyslog", "../radiusd-auth", "radiusd-auth; reboot", "s6rc-oneshot-runner"} {
		if containerServiceAllowed(name) {
			t.Errorf("%q must be refused", name)
		}
	}
}

func TestParseS6Svstat(t *testing.T) {
	var up ContainerService
	if err := parseS6Svstat("true true 374667 -1 NA 72656", &up); err != nil {
		t.Fatal(err)
	}
	if !up.Up || !up.WantedUp || up.PID != 374667 || up.SinceSeconds != 72656 || up.ExitCode != nil || up.Signal != "" {
		t.Errorf("unexpected up state: %+v", up)
	}
	var down ContainerService
	if err := parseS6Svstat("false false 0 1 NA 12", &down); err != nil {
		t.Fatal(err)
	}
	if down.Up || down.WantedUp || down.PID != 0 || down.SinceSeconds != 12 || down.ExitCode == nil || *down.ExitCode != 1 || down.Signal != "" {
		t.Errorf("unexpected down state: %+v", down)
	}
	var killed ContainerService
	if err := parseS6Svstat("false true 0 -1 SIGTERM 1", &killed); err != nil {
		t.Fatal(err)
	}
	if killed.Up || !killed.WantedUp || killed.ExitCode != nil || killed.Signal != "SIGTERM" {
		t.Errorf("unexpected killed state: %+v", killed)
	}
	if err := parseS6Svstat("garbage", &ContainerService{}); err == nil {
		t.Error("garbage must be refused")
	}
}

func TestContainerServicesStatus(t *testing.T) {
	withFakeS6(t, map[string]string{
		"radiusd-auth":         "true true 4242 -1 NA 100",
		"fingerbank-collector": "true true 4343 -1 NA 50",
		// connector-cache is not supervised: s6-svstat fails
	})
	state := containerServices()
	if state == nil || len(state.Services) != 3 {
		t.Fatalf("expected the three services, got %+v", state)
	}
	if state.Services[0].Name != "radiusd-auth" || !state.Services[0].Up || state.Services[0].PID != 4242 || state.Services[0].Description == "" {
		t.Errorf("unexpected radiusd-auth: %+v", state.Services[0])
	}
	if state.Services[1].Name != "connector-cache" || state.Services[1].Up || state.Services[1].Error == "" {
		t.Errorf("unexpected connector-cache: %+v", state.Services[1])
	}
	if state.Services[2].Name != "fingerbank-collector" || !state.Services[2].Up || state.Services[2].PID != 4343 || state.Services[2].SinceSeconds != 50 {
		t.Errorf("unexpected fingerbank-collector: %+v", state.Services[2])
	}

	// without s6-svstat (outside the container) nothing is reported
	old := s6SvstatBinary
	s6SvstatBinary = filepath.Join(t.TempDir(), "missing")
	defer func() { s6SvstatBinary = old }()
	if containerServices() != nil {
		t.Error("no state expected without s6-svstat")
	}
}

func TestContainerServiceRestart(t *testing.T) {
	svcLog := withFakeS6(t, map[string]string{
		"radiusd-auth":    "true true 4242 -1 NA 100",
		"connector-cache": "false false 0 1 NA 12",
	})
	api := &API{ctx: context.Background()}
	post := func(body string) *httptest.ResponseRecorder {
		rec := httptest.NewRecorder()
		containerServiceRestart(api).ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/api/v1/container-service/restart", bytes.NewBufferString(body)))
		return rec
	}

	// a running service is restarted (-r), a stopped one brought up (-u)
	if rec := post(`{"service":"radiusd-auth"}`); rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	} else {
		var reply map[string]string
		if err := json.Unmarshal(rec.Body.Bytes(), &reply); err != nil || reply["service"] != "radiusd-auth" || reply["action"] != "restart" {
			t.Errorf("unexpected reply %s", rec.Body.String())
		}
	}
	if rec := post(`{"service":"connector-cache"}`); rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}
	log, _ := os.ReadFile(svcLog)
	calls := strings.Split(strings.TrimSpace(string(log)), "\n")
	if len(calls) != 2 || !strings.HasPrefix(calls[0], "-r ") || !strings.HasSuffix(calls[0], "/radiusd-auth") || !strings.HasPrefix(calls[1], "-u ") || !strings.HasSuffix(calls[1], "/connector-cache") {
		t.Errorf("unexpected s6-svc calls: %q", calls)
	}

	// refused: other services, missing name, bad body; s6-svc untouched
	for body, code := range map[string]int{
		`{"service":"keepalived"}`:         http.StatusForbidden,
		`{"service":"pfconnector-client"}`: http.StatusForbidden,
		`{"service":""}`:                   http.StatusBadRequest,
		`not json`:                         http.StatusBadRequest,
	} {
		if rec := post(body); rec.Code != code {
			t.Errorf("%s: expected %d, got %d: %s", body, code, rec.Code, rec.Body.String())
		}
	}
	log, _ = os.ReadFile(svcLog)
	if n := len(strings.Split(strings.TrimSpace(string(log)), "\n")); n != 2 {
		t.Errorf("refused requests must not reach s6-svc, got %d calls", n)
	}

	// allowed but not supervised in this container
	if err := os.RemoveAll(filepath.Join(s6ServiceDir, "connector-cache")); err != nil {
		t.Fatal(err)
	}
	if rec := post(`{"service":"connector-cache"}`); rec.Code != http.StatusNotFound {
		t.Errorf("expected 404 for an unsupervised service, got %d: %s", rec.Code, rec.Body.String())
	}
}
