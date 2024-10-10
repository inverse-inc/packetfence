package apiaaa

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/caddyserver/caddy/v2/caddytest"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/julienschmidt/httprouter"
)

var ctx = log.LoggerNewContext(context.Background())
var apiAAA = buildApiAAAHandler(ctx)

func buildApiAAAHandler(ctx context.Context) *ApiAAAHandler {
	a := ApiAAAHandler{}
	a.buildApiAAAHandler(ctx)
	return &a
}

func TestApiAAALogin(t *testing.T) {
	ctx := context.Background()
	webservices := pfconfigdriver.GetStruct(ctx, "PfConfWebservices").(*pfconfigdriver.PfConfWebservices)
	req, _ := http.NewRequest(
		"POST",
		"/login",
		bytes.NewBuffer([]byte(fmt.Sprintf(`{"username":"%s", "password":"%s"}`, webservices.User, webservices.Pass))),
	)

	recorder := httptest.NewRecorder()
	apiAAA.handleLogin(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusOK {
		t.Error("Wrong status code from handleStart")
	}

	req, _ = http.NewRequest(
		"POST",
		"/login",
		bytes.NewBuffer([]byte(fmt.Sprintf(`{"username":"%s", "password":"badPwd"}`, webservices.User))),
	)

	recorder = httptest.NewRecorder()
	apiAAA.handleLogin(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusUnauthorized {
		t.Error("Wrong status code from handleStart")
	}

}

func TestApiAAATokenInfo(t *testing.T) {
	webservices := pfconfigdriver.GetStruct(ctx, "PfConfWebservices").(*pfconfigdriver.PfConfWebservices)
	_, token, _ := apiAAA.authentication.Login(ctx, webservices.User, webservices.Pass)
	tokenInfo, _ := apiAAA.authorization.GetTokenInfo(ctx, token)

	req, _ := http.NewRequest("GET", "/api/v1/token_info", nil)
	req.Header.Add("Authorization", "Bearer "+token)

	recorder := httptest.NewRecorder()
	apiAAA.handleTokenInfo(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusOK {
		t.Error("Wrong status code from HandleAAA")
	}

	prettyInfo := &PrettyTokenInfo{}
	respMap := struct {
		Item *PrettyTokenInfo
	}{Item: prettyInfo}
	b, _ := ioutil.ReadAll(recorder.Body)
	err := json.Unmarshal(b, &respMap)
	sharedutils.CheckError(err)

	for _, r := range respMap.Item.AdminRoles {
		if _, ok := tokenInfo.AdminRoles[r]; !ok {
			t.Errorf("Missing admin role %s in token info response", r)
		}
	}

	if respMap.Item.Username != webservices.User {
		t.Error("Username in token info isn't valid:", respMap.Item.Username)
	}
}

func TestApiAAAHandleAAA(t *testing.T) {
	webservices := pfconfigdriver.GetStruct(ctx, "PfConfWebservices").(*pfconfigdriver.PfConfWebservices)
	// The webservices credentials should have access to everything
	req, _ := http.NewRequest(
		"POST",
		"/login",
		bytes.NewBuffer([]byte(fmt.Sprintf(`{"username":"%s", "password":"%s"}`, webservices.User, webservices.Pass))),
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

func TestApiAAAContentType(t *testing.T) {

	webservices := pfconfigdriver.GetStruct(ctx, "PfConfWebservices").(*pfconfigdriver.PfConfWebservices)
	req, _ := http.NewRequest(
		"POST",
		"/login",
		bytes.NewBuffer([]byte(fmt.Sprintf(`{"username":"%s", "password":"%s"}`, webservices.User, webservices.Pass))),
	)

	recorder := httptest.NewRecorder()
	apiAAA.ServeHTTP(recorder, req, nil)

	if recorder.Header().Get("Content-Type") != "application/json" {
		t.Error("Wrong Content-Type for the request")
	}

}

func TestRespond(t *testing.T) {
	// arrange
	tester := caddytest.NewTester(t)
	tester.InitServer(` 
  {
    admin localhost:2999
    http_port     9080
    https_port    9443
    grace_period  1ns
  }
  
  localhost:9080 {
	  route * {
		  api-aaa {
			  no_auth /api/v1/pfconnector/tunnel
		  }
	  }
    }
  `, "caddyfile")

	// act and assert
	tester.AssertGetResponse("http://localhost:9080/api/v1/pfconnector/tunnel", 200, "")

}
