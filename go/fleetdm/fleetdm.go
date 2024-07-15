package fleetdm

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"io/ioutil"
	"net/http"
	"sync"
	"time"
)

var mLock sync.Mutex

type fleetDMCfgS struct {
	host     string
	email    string
	password string
	token    string // for perpetual API user only
}
type CachedTokenS struct {
	Token     string
	ExpiresAt time.Time
}

var cfg = &fleetDMCfgS{}
var FDMToken = &CachedTokenS{
	Token:     "",
	ExpiresAt: time.Now(),
}

func init() {
	cfg.host = ""
	cfg.email = ""
	cfg.password = ""
	cfg.token = ""
}

func GetFleetDMConfig(ctx context.Context) (pfconfigdriver.FleetDM, error) {
	var c pfconfigdriver.FleetDM
	err := pfconfigdriver.FetchDecodeSocket(ctx, &c)
	return c, err
}

func CachedGetToken(email string, password string) (string, error) {
	mLock.Lock()
	defer mLock.Unlock()

	if FDMToken.Token != "" && time.Now().Before(FDMToken.ExpiresAt) {
		return FDMToken.Token, nil
	}

	token, err := Login(email, password)
	if err != nil {
		return "", err
	}

	FDMToken.Token = token
	FDMToken.ExpiresAt = time.Now().Add(5 * time.Minute)
	return token, nil
}

func Login(email string, password string) (string, error) {
	url := cfg.host + "/api/v1/fleet/login"
	payload, err := json.Marshal(map[string]string{
		"email":    email,
		"password": password,
	})
	if err != nil {
		return "", err
	}

	buffer := bytes.NewBuffer(payload)
	response, err := (&http.Client{Timeout: 2 * time.Second}).Post(url, "application/json", buffer)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()

	statusCode := response.StatusCode
	body, err := ioutil.ReadAll(response.Body)
	if err != nil {
		return "", err
	}

	if statusCode == http.StatusOK {
		FDMUser := &LoginResponse{}
		err = json.Unmarshal(body, FDMUser)
		if err != nil {
			return "", errors.New("unable to parse login response: " + err.Error())
		}
		return FDMUser.Token, nil
	}
	if statusCode == http.StatusUnauthorized {
		return "", errors.New("http 401 unauthorized: maybe you are using wrong email or password")
	}
	if statusCode == http.StatusTooManyRequests {
		retry := response.Header.Get("retry-after")
		return "", errors.New(fmt.Sprintf("http 429 too many request: retry after %s seconds", retry))
	}
	return "", errors.New(fmt.Sprintf("http %d : %s", statusCode, string(body)))
}

func GetHost(id int) (*Host, error) {
	h := &Host{}

	token, err := CachedGetToken(cfg.email, cfg.password)
	if err != nil {
		return h, nil
	}

	url := fmt.Sprintf("%s/api/v1/fleet/hosts/%d", cfg.host, id)
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", token))

	resp, err := (&http.Client{}).Do(req)
	if err != nil {
		return h, err
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return h, err
	}

	hostResp := &HostResponse{}
	err = json.Unmarshal(body, hostResp)
	if err != nil {
		return h, err
	}
	return &(hostResp.Host), nil
}
