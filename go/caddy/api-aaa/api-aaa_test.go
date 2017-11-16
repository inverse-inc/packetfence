package apiaaa

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/inverse-inc/packetfence/go/log"
	"github.com/julienschmidt/httprouter"
)

var ctx = log.LoggerNewContext(context.Background())
var apiAAA, err = buildApiAAAHandler(ctx)

func TestApiAAALogin(t *testing.T) {
	req, _ := http.NewRequest(
		"POST",
		"/login",
		bytes.NewBuffer([]byte(`{"username":"web", "password":"services"}`)),
	)

	recorder := httptest.NewRecorder()
	apiAAA.handleLogin(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusOK {
		t.Error("Wrong status code from handleStart")
	}

	req, _ = http.NewRequest(
		"POST",
		"/login",
		bytes.NewBuffer([]byte(`{"username":"web", "password":"badPwd"}`)),
	)

	recorder = httptest.NewRecorder()
	apiAAA.handleLogin(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusUnauthorized {
		t.Error("Wrong status code from handleStart")
	}

}

func TestApiAAAHandleAAA(t *testing.T) {

	// The webservices credentials should have access to everything
	req, _ := http.NewRequest(
		"POST",
		"/login",
		bytes.NewBuffer([]byte(`{"username":"web", "password":"services"}`)),
	)

	recorder := httptest.NewRecorder()
	apiAAA.handleLogin(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusOK {
		t.Error("Wrong status code from handleStart")
	}

	var tokenResp map[string]string
	json.Unmarshal([]byte(recorder.Body.String()), &tokenResp)

	token := tokenResp["token"]

	if token == "" {
		t.Error("Unable to get token to validate AAA")
	}

	req, _ = http.NewRequest("GET", "/something-that-will-hopefuly-never-exist", nil)
	req.Header.Add("Authorization", "Bearer "+token)

	recorder = httptest.NewRecorder()
	apiAAA.HandleAAA(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Error("Wrong status code from HandleAAA")
	}

}
