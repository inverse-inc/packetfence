package jobstatus

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfqueueclient"
	"github.com/julienschmidt/httprouter"
)

func TestJobStatusHandleStatus(t *testing.T) {
	ctxLog := log.LoggerNewContext(context.Background())
	jobStatus := &JobStatusHandler{}
	jobStatus.buildJobStatusHandler(ctxLog)
	req, _ := http.NewRequest(
		"GET",
		"/api/v1/pfqueue/task/not_important_check_the_params_below/status",
		nil,
	)

	ctx := context.Background()

	_, err := jobStatus.redis.FlushAll(ctx).Result()
	sharedutils.CheckError(err)

	recorder := httptest.NewRecorder()
	jobStatus.handleStatus(recorder, req, httprouter.Params{httprouter.Param{Key: "job_id", Value: "non-existant"}})

	if recorder.Code != http.StatusNotFound {
		t.Error("Wrong status code from handleStatus")
	}

	jobId := "test"
	_, err = jobStatus.redis.HSet(ctx, jobId, "something", "todo").Result()
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

	_, err = jobStatus.redis.HSet(ctx, jobStatus.jobStatusKey(jobId), "status", "200").Result()
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

	_, err = jobStatus.redis.FlushAll(ctx).Result()
	sharedutils.CheckError(err)

	recorder = httptest.NewRecorder()
	jobStatus.handleStatus(recorder, req, httprouter.Params{httprouter.Param{Key: "job_id", Value: jobId}})

	if recorder.Code != http.StatusNotFound {
		t.Error("Wrong status code from handleStatus")
	}

}

//{"progress":"0","status":202,"status_msg":"In Progress"}

type Results struct {
}

func TestStatusUpdater(t *testing.T) {
	ctxLog := log.LoggerNewContext(context.Background())
	jobStatus := &JobStatusHandler{}
	jobStatus.buildJobStatusHandler(ctxLog)
	req, _ := http.NewRequest(
		"GET",
		"/api/v1/pfqueue/task/not_important_check_the_params_below/status",
		nil,
	)

	ctx := context.Background()

	_, err := jobStatus.redis.FlushAll(ctx).Result()
	sharedutils.CheckError(err)

	taskId := pfqueueclient.NewApiTaskID()
	recorder := httptest.NewRecorder()
	jobStatus.handleStatus(recorder, req, httprouter.Params{httprouter.Param{Key: "job_id", Value: taskId}})
	if recorder.Code != http.StatusNotFound {
		t.Error("Wrong status code from handleStatus")
	}
	sq := pfqueueclient.NewStatusUpdater(taskId, time.Hour, jobStatus.redis)
	err = sq.Start(ctx)
	if err != nil {
		t.Fatalf("Cannot start: %v", err)
	}

	recorder = httptest.NewRecorder()
	jobStatus.handleStatusPoll(recorder, req, httprouter.Params{httprouter.Param{Key: "job_id", Value: taskId}})
	if recorder.Code != http.StatusOK {
		t.Errorf("Wrong status code from handleStatus exepected %d got %d", http.StatusAccepted, recorder.Code)
	}

	go func() {
		time.Sleep(2 * time.Second)
		err = sq.Complete(ctx, struct{}{})
		fmt.Printf("Done")
	}()
	recorder = httptest.NewRecorder()
	jobStatus.handleStatusPoll(recorder, req, httprouter.Params{httprouter.Param{Key: "job_id", Value: taskId}})
	if recorder.Code != http.StatusOK {
		t.Errorf("Wrong status code from handleStatus exepected %d got %d", http.StatusAccepted, recorder.Code)
	}
}
