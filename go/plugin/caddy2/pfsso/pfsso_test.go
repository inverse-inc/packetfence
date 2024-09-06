package pfsso

import (
	"bytes"
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/firewallsso"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/julienschmidt/httprouter"
)

func TestMain(m *testing.M) {
	ctx := context.Background()
	firewalls := firewallsso.NewFirewallsContainer(ctx)
	pfconfigdriver.AddRefreshable(ctx, "firewallsso.FirewallsContainer", firewalls)
}

func TestValidateInfo(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())
	pfsso := &PfssoHandler{}
	err := pfsso.buildPfssoHandler(ctx)
	sharedutils.CheckTestError(t, err)

	// Test valid info
	info := map[string]string{"ip": "1.2.3.4", "mac": "00:11:22:33:44:55", "username": "lzammit", "role": "default"}

	if pfsso.validateInfo(ctx, info) != nil {
		t.Error("Validate info failed with valid informations")
	}

	// Test missing ip
	info = map[string]string{"mac": "00:11:22:33:44:55", "username": "lzammit", "role": "default"}

	if pfsso.validateInfo(ctx, info) == nil {
		t.Error("Validate info succeeded with invalid informations")
	}

	// Test missing mac
	info = map[string]string{"ip": "1.2.3.4", "username": "lzammit", "role": "default"}

	if pfsso.validateInfo(ctx, info) == nil {
		t.Error("Validate info succeeded with invalid informations")
	}

	// Test missing username
	info = map[string]string{"ip": "1.2.3.4", "mac": "00:11:22:33:44:55", "role": "default"}

	if pfsso.validateInfo(ctx, info) == nil {
		t.Error("Validate info succeeded with invalid informations")
	}

	// Test missing role
	info = map[string]string{"ip": "1.2.3.4", "mac": "00:11:22:33:44:55", "username": "lzammit"}

	if pfsso.validateInfo(ctx, info) == nil {
		t.Error("Validate info succeeded with invalid informations")
	}

	// Test empty info
	info = map[string]string{}

	if pfsso.validateInfo(ctx, info) == nil {
		t.Error("Validate info succeeded with invalid informations")
	}
}

func TestParseSsoRequest(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())
	pfsso := &PfssoHandler{}
	err := pfsso.buildPfssoHandler(ctx)
	sharedutils.CheckTestError(t, err)
	// Valid payload with timeout
	b := bytes.NewBuffer([]byte(`{"ip":"1.2.3.4", "mac": "00:11:22:33:44:55", "username":"lzammit", "role": "default", "timeout":"86400"}`))
	r, _ := http.NewRequest("POST", "/", b)
	info, timeout, err := pfsso.parseSsoRequest(ctx, r)

	if err != nil {
		t.Errorf("Valid payload yielded error: %s", err)
	}

	if info == nil {
		t.Error("Valid payload yielded a nil info")
	}

	expected := 86400
	if timeout != expected {
		t.Errorf("Expected timeout %d but got %d", expected, timeout)
	}

	infoExpected := map[string]string{"ip": "1.2.3.4", "mac": "00:11:22:33:44:55", "username": "lzammit", "role": "default", "timeout": "86400"}
	for k, expectedV := range infoExpected {
		if v, ok := info[k]; ok {
			if v != expectedV {
				t.Errorf("Expected %s for key %s but got %s instead", expectedV, k, v)
			}
		} else {
			t.Errorf("Expected %s for key %s but does not exists", expectedV, k)
		}
	}

	//Valid payload without a timeout
	b = bytes.NewBuffer([]byte(`{"ip":"1.2.3.4", "mac": "00:11:22:33:44:55", "username":"lzammit", "role": "default"}`))
	r, _ = http.NewRequest("POST", "/", b)
	info, timeout, err = pfsso.parseSsoRequest(ctx, r)

	if err != nil {
		t.Errorf("Valid payload yielded error: %s", err)
	}

	if info == nil {
		t.Error("Valid payload yielded a nil info")
	}

	expected = 0
	if timeout != expected {
		t.Errorf("Expected timeout %d but got %d", expected, timeout)
	}

	//Invalid JSON payload
	b = bytes.NewBuffer([]byte(`{"ip":"1.2.3.4", "mac": "00:11:22:33:44:55", "username":"lzammit", "role": "default"`))
	r, _ = http.NewRequest("POST", "/", b)
	info, timeout, err = pfsso.parseSsoRequest(ctx, r)

	if err == nil {
		t.Error("Invalid payload didn't give an error")
	}

	if info != nil {
		t.Error("Invalid payload didn't provide a nil info")
	}

	expected = 0
	if timeout != expected {
		t.Errorf("Expected timeout %d but got %d", expected, timeout)
	}

	//Missing field in request
	b = bytes.NewBuffer([]byte(`{"ip":"1.2.3.4", "mac": "00:11:22:33:44:55", "username":"lzammit"}`))
	r, _ = http.NewRequest("POST", "/", b)
	info, timeout, err = pfsso.parseSsoRequest(ctx, r)

	if err == nil {
		t.Error("Invalid payload didn't give an error")
	}

	if info != nil {
		t.Error("Invalid payload didn't provide a nil info")
	}

	expected = 0
	if timeout != expected {
		t.Errorf("Expected timeout %d but got %d", expected, timeout)
	}
}

func TestHandleStart(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())
	pfsso := &PfssoHandler{}
	err := pfsso.buildPfssoHandler(ctx)
	sharedutils.CheckTestError(t, err)
	req := httptest.NewRequest("POST", "/pfsso/start", bytes.NewBuffer([]byte(`{"ip":"1.2.3.4", "mac": "00:11:22:33:44:55", "username":"lzammit", "role": "default", "timeout":"86400"}`)))
	recorder := httptest.NewRecorder()
	pfsso.handleStart(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusAccepted {
		t.Error("Wrong status code from handleStart")
	}

	// Test invalid JSON payload
	req = httptest.NewRequest("POST", "/pfsso/start", bytes.NewBuffer([]byte(`{"ip":"1.2.3.4", "mac": "00:11:22:33:44:55", "username":"lzammit", "role": "default", "timeout":"86400"`)))
	recorder = httptest.NewRecorder()
	pfsso.handleStart(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusBadRequest {
		t.Error("Wrong status code from handleStart")
	}

	// Test missing info
	req = httptest.NewRequest("POST", "/pfsso/start", bytes.NewBuffer([]byte(`{"ip":"1.2.3.4", "mac": "00:11:22:33:44:55", "username":"lzammit", "timeout":"86400"}`)))
	recorder = httptest.NewRecorder()
	pfsso.handleStart(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusBadRequest {
		t.Error("Wrong status code from handleStart")
	}

}

func TestHandleStop(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())
	pfsso := &PfssoHandler{}
	err := pfsso.buildPfssoHandler(ctx)
	sharedutils.CheckTestError(t, err)
	req := httptest.NewRequest("POST", "/pfsso/stop", bytes.NewBuffer([]byte(`{"ip":"1.2.3.4", "mac": "00:11:22:33:44:55", "username":"lzammit", "role": "default"}`)))
	recorder := httptest.NewRecorder()
	pfsso.handleStop(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusAccepted {
		t.Error("Wrong status code from handleStop")
	}

	// Test invalid JSON payload
	req = httptest.NewRequest("POST", "/pfsso/stop", bytes.NewBuffer([]byte(`{"ip":"1.2.3.4", "mac": "00:11:22:33:44:55", "username":"lzammit", "role": "default"`)))
	recorder = httptest.NewRecorder()
	pfsso.handleStart(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusBadRequest {
		t.Error("Wrong status code from handleStart")
	}

	// Test missing info
	req = httptest.NewRequest("POST", "/pfsso/stop", bytes.NewBuffer([]byte(`{"ip":"1.2.3.4", "mac": "00:11:22:33:44:55", "username":"lzammit"}`)))
	recorder = httptest.NewRecorder()
	pfsso.handleStart(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusBadRequest {
		t.Error("Wrong status code from handleStart")
	}

}

// Run this with -test.race to see the potential race conditions
func TestSpawnSso(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())
	pfsso := &PfssoHandler{}
	err := pfsso.buildPfssoHandler(ctx)
	sharedutils.CheckTestError(t, err)

	if err != nil {
		t.Error("Can't build PfssoHandler", err)
	}

	// Test multiple firewalls SSO at the same time
	info := map[string]string{
		"ip":       "1.2.3.4",
		"mac":      "00:11:22:33:44:55",
		"username": "bobbey",
		"role":     "default",
	}
	factory := firewallsso.NewFactory(ctx)
	firewall, _ := factory.Instantiate(ctx, "testfw2")

	for i := 0; i < 5; i++ {
		pfsso.spawnSso(ctx, firewall, info, func(ctx context.Context, info map[string]string) (bool, error) {
			return firewallsso.ExecuteStart(ctx, firewall, info, 3600)
		})
	}
}
