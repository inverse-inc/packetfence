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

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/julienschmidt/httprouter"
)

var ctx = log.LoggerNewContext(context.Background())
var apiAAA, err = buildApiAAAHandler(ctx, []string{})
var dummyHandler = caddyhttp.HandlerFunc(func(w http.ResponseWriter, r *http.Request) error { return nil })

func buildApiAAAHandler(ctx context.Context, args []string) (*ApiAAAHandler, error) {
	var h = &ApiAAAHandler{}
	err := h.Provision(caddy.Context{Context: ctx})
	if err != nil {
		return nil, err
	}
	return h, nil
}

func TestApiAAALogin(t *testing.T) {
	req, _ := http.NewRequest(
		"POST",
		"/login",
		bytes.NewBuffer([]byte(fmt.Sprintf(`{"username":"%s", "password":"%s"}`, pfconfigdriver.Config.PfConf.Webservices.User, pfconfigdriver.Config.PfConf.Webservices.Pass))),
	)

	recorder := httptest.NewRecorder()
	apiAAA.handleLogin(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusOK {
		t.Error("Wrong status code from handleStart")
	}

	req, _ = http.NewRequest(
		"POST",
		"/login",
		bytes.NewBuffer([]byte(fmt.Sprintf(`{"username":"%s", "password":"badPwd"}`, pfconfigdriver.Config.PfConf.Webservices.User))),
	)

	recorder = httptest.NewRecorder()
	apiAAA.handleLogin(recorder, req, httprouter.Params{})

	if recorder.Code != http.StatusUnauthorized {
		t.Error("Wrong status code from handleStart")
	}

}

func TestApiAAATokenInfo(t *testing.T) {
	_, token, _ := apiAAA.authentication.Login(ctx, pfconfigdriver.Config.PfConf.Webservices.User, pfconfigdriver.Config.PfConf.Webservices.Pass)
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

	if respMap.Item.Username != pfconfigdriver.Config.PfConf.Webservices.User {
		t.Error("Username in token info isn't valid:", respMap.Item.Username)
	}
}

func TestApiAAAHandleAAA(t *testing.T) {

	// The webservices credentials should have access to everything
	req, _ := http.NewRequest(
		"POST",
		"/login",
		bytes.NewBuffer([]byte(fmt.Sprintf(`{"username":"%s", "password":"%s"}`, pfconfigdriver.Config.PfConf.Webservices.User, pfconfigdriver.Config.PfConf.Webservices.Pass))),
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

	req, _ := http.NewRequest(
		"POST",
		"/login",
		bytes.NewBuffer([]byte(fmt.Sprintf(`{"username":"%s", "password":"%s"}`, pfconfigdriver.Config.PfConf.Webservices.User, pfconfigdriver.Config.PfConf.Webservices.Pass))),
	)

	recorder := httptest.NewRecorder()
	apiAAA.ServeHTTP(recorder, req, dummyHandler)

	if recorder.Header().Get("Content-Type") != "application/json" {
		t.Error("Wrong Content-Type for the request")
	}

}
