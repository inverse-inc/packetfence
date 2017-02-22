package pfsso

import (
	"bytes"
	"context"
	"github.com/fingerbank/processor/log"
	"github.com/julienschmidt/httprouter"
	"net/http"
	"net/http/httptest"
	"testing"
)

var ctx = log.LoggerNewContext(context.Background())
var pfsso, err = buildPfssoHandler(ctx)

func TestHandleStart(t *testing.T) {
	req := httptest.NewRequest("POST", "/pfsso/start", bytes.NewBuffer([]byte(`{"ip":"1.2.3.4", "mac": "00:11:22:33:44:55", "username":"lzammit", "role": "default", "timeout":"86400"}`)))
	recorder := httptest.NewRecorder()
	pfsso.handleStart(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusAccepted {
		t.Error("Wrong status code from handleStart")
	}

}

func TestHandleStop(t *testing.T) {
	req := httptest.NewRequest("POST", "/pfsso/stop", bytes.NewBuffer([]byte(`{"ip":"1.2.3.4", "mac": "00:11:22:33:44:55", "username":"lzammit", "role": "default", "timeout":"86400"}`)))
	recorder := httptest.NewRecorder()
	pfsso.handleStop(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusAccepted {
		t.Error("Wrong status code from handleStop")
	}

}
