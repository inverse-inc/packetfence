package handlers_test

import (
	"net/http"
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/internal/testutil"
)

// Processing the cloud revocations changes state (here and in the cloud
// service): it is a POST, a GET is refused.
func TestProcessCloudRevocations_PostOnly(t *testing.T) {
	env := testutil.NewEnv(t)
	for method, want := range map[string]int{
		http.MethodGet:  http.StatusMethodNotAllowed,
		http.MethodPost: http.StatusOK,
	} {
		req, _ := http.NewRequest(method, env.Server.URL+"/api/v1/pki/process_cloud_revocations", nil)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		resp.Body.Close()
		if resp.StatusCode != want {
			t.Errorf("%s: status %d, want %d", method, resp.StatusCode, want)
		}
	}
}
