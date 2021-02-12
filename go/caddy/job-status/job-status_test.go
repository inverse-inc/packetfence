package jobstatus

import (
	"context"
	"encoding/json"
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

	if recorder.Code != http.StatusAccepted {
		t.Error("Wrong status code from handleStatus")
	}

	var results map[string]interface{}
	if json.Unmarshal(b, &results) != nil {
		t.Error("Invalid json returned")
	}

	if 202 != results["status"].(float64) {
		t.Error("Wrong data for job status")
	}

	_, err = jobStatus.redis.HSet(jobStatus.jobStatusKey(jobId), "status", "200").Result()
	sharedutils.CheckError(err)

	recorder = httptest.NewRecorder()
	jobStatus.handleStatus(recorder, req, httprouter.Params{httprouter.Param{Key: "job_id", Value: jobId}})

	b, _ = ioutil.ReadAll(recorder.Body)

	if recorder.Code != http.StatusOK {
		t.Error("Wrong status code from handleStatus")
	}

	if json.Unmarshal(b, &results) != nil {
		t.Error("Invalid json returned")
	}

	if 200 != results["status"].(float64) {
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
