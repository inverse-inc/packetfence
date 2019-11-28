package firewallsso

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"sync"

	"github.com/davecgh/go-spew/spew"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

type CiscoIsePic struct {
	FirewallSSO
	Username string `json:"username"`
	Password string `json:"password"`
	Port     string `json:"port"`

	token     string
	tokenLock *sync.RWMutex
}

// Firewall specific init
func (fw *CiscoIsePic) initChild(ctx context.Context) error {
	fw.tokenLock = &sync.RWMutex{}
	return nil
}

func (fw *CiscoIsePic) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	log.LoggerWContext(ctx).Info("Sending SSO to CiscoIsePic using HTTP")
	return fw.startHttp(ctx, info, timeout)
}

func (fw *CiscoIsePic) getToken(ctx context.Context) (string, error) {
	req, err := http.NewRequest("POST", fmt.Sprintf("https://%s:%s/api/fmi_platform/v1/identityauth/generatetoken", fw.PfconfigHashNS, fw.Port), nil)
	req.SetBasicAuth(fw.Username, fw.Password)
	sharedutils.CheckError(err)
	resp, err := fw.getHttpClient(ctx).Do(req)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting firewall during getToken: %s", err))
		return "", err
	} else if resp.StatusCode == 401 {
		msg := "Invalid username/password to connect on the ISE-PIC API"
		return "", errors.New(msg)
	} else {
		spew.Dump(resp.StatusCode)

		token := resp.Header.Get("X-auth-access-token")
		log.LoggerWContext(ctx).Debug(fmt.Sprintf("Obtained token '%s' for ISE-PIC server", token))
		return token, nil
	}
}

func (fw *CiscoIsePic) doRequest(ctx context.Context, req *http.Request, hasTried bool) (*http.Response, error) {
	fw.tokenLock.RLock()
	req.Header.Set("X-auth-access-token", fw.token)
	fw.tokenLock.RUnlock()

	req2 := req.Clone(context.Background())
	body, err := ioutil.ReadAll(req.Body)
	sharedutils.CheckError(err)
	req2.Body = ioutil.NopCloser(bytes.NewReader(body))
	req.Body = ioutil.NopCloser(bytes.NewReader(body))

	resp, err := fw.getHttpClient(ctx).Do(req2)
	if err != nil {
		return resp, err
	} else if resp.StatusCode == 401 {
		if hasTried {
			msg := "Unable to get a valid access token for the ISE-PIC API"
			return resp, errors.New(msg)
		} else {
			log.LoggerWContext(ctx).Info(fmt.Sprintf("Invalid access token when communicating with ISE-PIC. Will obtain a new token"))
			token, err := fw.getToken(ctx)
			if err != nil {
				return resp, err
			} else {
				// Update the token and retry the request
				fw.tokenLock.Lock()
				fw.token = token
				fw.tokenLock.Unlock()
				return fw.doRequest(ctx, req, true)
			}
		}
	} else {
		return resp, nil
	}
}

func (fw *CiscoIsePic) startHttp(ctx context.Context, info map[string]string, timeoutInt int) (bool, error) {
	domain := info["realm"]
	if domain == "" {
		domain = "null"
	}
	timeout := info["timeout"]
	if timeout == "" {
		timeout = "0"
	}
	payload, err := json.Marshal(map[string]string{
		"user":         info["username"],
		"srcIpAddress": info["ip"],
		"timeout":      timeout,
		"domain":       domain,
	})

	log.LoggerWContext(ctx).Debug("Sending the following payload: " + string(payload))

	req, err := http.NewRequest("POST", fmt.Sprintf("https://%s:%s/api/identity/v1/identity/useridentity", fw.PfconfigHashNS, fw.Port), bytes.NewBuffer(payload))
	sharedutils.CheckError(err)
	req.Header.Add("Content-Type", "application/json")
	resp, err := fw.doRequest(ctx, req, false)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting Cisco ISE-PIC: %s", err))
		//Not returning now so that body closes below
	}

	if resp != nil && resp.Body != nil {
		if resp.StatusCode != 201 {
			body, _ := ioutil.ReadAll(resp.Body)
			log.LoggerWContext(ctx).Error("Unable to create session on ISE-PIC: ", body)
		} else {
			log.LoggerWContext(ctx).Debug("Created session on ISE-PIC")
		}
		resp.Body.Close()
	}

	return err == nil, err
}

func (fw *CiscoIsePic) Stop(ctx context.Context, info map[string]string) (bool, error) {
	log.LoggerWContext(ctx).Warn("SSO Stop isn't supported on Cisco ISE-PIC.")
	return false, nil
}
