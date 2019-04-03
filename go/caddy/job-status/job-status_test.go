package jobstatus

import (
	"context"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/julienschmidt/httprouter"
)

var ctx = log.LoggerNewContext(context.Background())
var jobStatus, _ = buildJobStatusHandler(ctx)

func TestJobStatusHandleStatus(t *testing.T) {
	req, _ := http.NewRequest(
		"GET",
		"/api/v1/pfqueue/task/not_important_check_the_params_below/status",
		nil,
	)

	_, err := jobStatus.redis.FlushAll().Result()
	sharedutils.CheckError(err)

	recorder := httptest.NewRecorder()
	jobStatus.handleStatus(recorder, req, httprouter.Params{httprouter.Param{Key: "job_id", Value: "non-existant"}})

	if recorder.Code != http.StatusNotFound {
		t.Error("Wrong status code from handleStatus")
	}

	jobId := "test"
	_, err = jobStatus.redis.HSet(jobId, "something", "todo").Result()
	sharedutils.CheckError(err)

	recorder = httptest.NewRecorder()
	jobStatus.handleStatus(recorder, req, httprouter.Params{httprouter.Param{Key: "job_id", Value: jobId}})

	b, _ := ioutil.ReadAll(recorder.Body)
	data := string(b)

	if recorder.Code != http.StatusOK {
		t.Error("Wrong status code from handleStatus")
	}

	if data != `{"status":"Pending"}` {
		t.Error("Wrong data for job status")
	}

	_, err = jobStatus.redis.HSet(jobStatus.jobStatusKey(jobId), "status", "Testing").Result()
	sharedutils.CheckError(err)

	recorder = httptest.NewRecorder()
	jobStatus.handleStatus(recorder, req, httprouter.Params{httprouter.Param{Key: "job_id", Value: jobId}})

	b, _ = ioutil.ReadAll(recorder.Body)
	data = string(b)

	if recorder.Code != http.StatusOK {
		t.Error("Wrong status code from handleStatus")
	}

	if data != `{"status":"Testing"}` {
		t.Error("Wrong data for job status")
	}

	_, err = jobStatus.redis.FlushAll().Result()
	sharedutils.CheckError(err)

	recorder = httptest.NewRecorder()
	jobStatus.handleStatus(recorder, req, httprouter.Params{httprouter.Param{Key: "job_id", Value: jobId}})

	if recorder.Code != http.StatusNotFound {
		t.Error("Wrong status code from handleStatus")
	}

}
