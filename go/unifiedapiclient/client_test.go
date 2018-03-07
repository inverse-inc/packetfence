package unifiedapiclient

import (
	"context"
	"flag"
	"io/ioutil"
	"testing"

	"github.com/inverse-inc/packetfence/go/sharedutils"
)

var testCtx = context.Background()

var shouldTestApi = flag.Bool("test-integration-api-frontend", false, "Should the integration test on the API frontend be run.")

func TestClientBuildRequest(t *testing.T) {
	c := NewFromConfig(testCtx)

	base := "https://127.0.0.1:9999"
	method := "POST"
	path := "/api/v1/login"
	body := `{"username": "test", "password": "test"}`

	r := c.buildRequest(testCtx, method, path, body)

	if r.Method != method {
		t.Error("Wrong method in the request")
	}

	if r.URL.String() != base+path {
		t.Error("Wrong URL in the request")
	}

	b, err := ioutil.ReadAll(r.Body)
	sharedutils.CheckError(err)
	if string(b) != body {
		t.Error("Wrong body in the request")
	}

	if r.Header.Get("Authorization") != "" {
		t.Error("An authorization header was set although the token is empty")
	}

	// Now test with the token

	c.token = "19216853"
	r = c.buildRequest(testCtx, method, path, body)

	if r.Header.Get("Authorization") != "Bearer 19216853" {
		t.Error("An authorization header was set although the token is empty")
	}

}

func TestClientRequest(t *testing.T) {
	flag.Parse()
	if *shouldTestApi {
		c := NewFromConfig(testCtx)
		err := c.Call(testCtx, "POST", "/api/v1/ipset/unmark_mac/00:11:22:33:44:55?local=1", &DummyReply{})

		if err != nil {
			t.Error("Error while contacting Unified API", err)
		}
	}
}
