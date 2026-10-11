package pfipset

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHandleIsolationPassthroughUsesIsolationSet(t *testing.T) {
	IPSET := &pfIPSET{jobs: make(chan job, 1)}
	ctx := context.WithValue(context.Background(), "IPSET", IPSET)

	req := httptest.NewRequest("POST", "/api/v1/ipset/passthrough_isolation?local=1", strings.NewReader(`{"ip":"192.0.2.10","port":"tcp:443"}`))
	req = req.WithContext(ctx)
	res := httptest.NewRecorder()

	handleIsolationPassthrough(res, req)

	if res.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", res.Code)
	}

	select {
	case j := <-IPSET.jobs:
		if j.Method != "Add" {
			t.Errorf("expected an Add job, got %s", j.Method)
		}
		if j.Set != "pfsession_isol_passthrough" {
			t.Errorf("expected the entry to be added to pfsession_isol_passthrough, got %s", j.Set)
		}
	default:
		t.Fatal("no ipset job was queued")
	}
}
