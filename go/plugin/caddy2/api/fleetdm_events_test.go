package api

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"testing"
)

type pfqueueResponse struct {
	TaskKey string `json:"task_key"`
}

func TestFleetDMPolicy(t *testing.T) {
	var testPayload = `{
		"timestamp": "2024-05-27T20:27:40.274362577Z",
		"policy": {
			"id": 12,
			"name": "test_policy_regex__",
			"query": "SELECT (total_seconds / 86400) AS uptime_in_days FROM uptime WHERE uptime_in_days \u003c 5;",
			"critical": false,
			"description": "aaa",
			"author_id": 1,
			"author_name": "admin",
			"author_email": "stgmsa@gmail.com",
			"team_id": null,
			"resolution": "aaa",
			"platform": "darwin,windows,linux",
			"calendar_events_enabled": false,
			"created_at": "2024-05-27T20:27:07Z",
			"updated_at": "2024-05-27T20:27:07Z",
			"passing_host_count": 0,
			"failing_host_count": 0,
			"host_count_updated_at": null
		},
		"hosts": [
			{
				"id": 3,
				"hostname": "localhost",
				"display_name": "",
				"url": "https://fleet.stgmsa.me:8080/hosts/1"
			}
		]}`

	h := APIHandler{}
	req := httptest.NewRequest(
		"POST",
		"/api/v1/fleetdm/policy",
		bytes.NewBufferString(testPayload),
	)
	w := httptest.NewRecorder()
	h.Policy(w, req, nil)
	resp := w.Result()
	body, _ := ioutil.ReadAll(resp.Body)

	if w.Code != http.StatusAccepted {
		t.Error("FleetDM API responsed with non-202 code: ", w.Code)
	}

	j := &pfqueueResponse{}
	err := json.Unmarshal(body, j)
	if err != nil {
		t.Error("Can not unmarshal FleetDM API response.", err.Error())
	}

	if len(j.TaskKey) <= 10 {
		t.Error("Unexpected pfqueue task key length")
	}
}

func TestFleetDMCVE(t *testing.T) {
	var testPayload = `
		{
		  "timestamp": "0000-00-00T00:00:00Z",
		  "vulnerability": {
			"cve": "CVE-2014-9471",
			"details_link": "https://nvd.nist.gov/vuln/detail/CVE-2014-9471",
			"cve_published": "2014-10-10T00:00:00Z",
			"cvss_score" : 9,
			"hosts_affected": [
			  {
				"id": 1,
				"display_name": "macbook-1",
				"url": "https://fleet.example.com/hosts/1",
				"software_installed_paths": [
				  "/usr/lib/some-path"
				]
			  },
			  {
				"id": 3,
				"display_name": "macbook-2",
				"url": "https://fleet.example.com/hosts/2"
			  }
			]
		  }
		}`

	h := APIHandler{}
	req := httptest.NewRequest(
		"POST",
		"/api/v1/fleetdm/cve",
		bytes.NewBufferString(testPayload),
	)
	w := httptest.NewRecorder()
	h.CVE(w, req, nil)
	resp := w.Result()
	body, _ := ioutil.ReadAll(resp.Body)

	if w.Code != http.StatusAccepted {
		t.Error("FleetDM API responsed with non-202 code: ", w.Code)
	}

	j := &pfqueueResponse{}
	err := json.Unmarshal(body, j)
	if err != nil {
		t.Error("Can not unmarshal FleetDM API response.", err.Error())
	}

	if len(j.TaskKey) <= 10 {
		t.Error("Unexpected pfqueue task key length")
	}
}
