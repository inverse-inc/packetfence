package apiaaa

import (
	"bytes"
	"context"
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
