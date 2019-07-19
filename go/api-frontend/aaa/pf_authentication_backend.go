package aaa

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"io/ioutil"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
)

type PfAuthenticationBackend struct {
	url        *url.URL
	httpClient *http.Client
}

type PfAuthenticationReply struct {
	Result   int
	Roles    []string
	TenantId int `json:"tenant_id"`
}

func NewPfAuthenticationBackend(ctx context.Context, url *url.URL, checkCert bool) *PfAuthenticationBackend {
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.AdminRoles)

	tr := &http.Transport{
		MaxIdleConnsPerHost:   30,
		TLSHandshakeTimeout:   1 * time.Second,
		ResponseHeaderTimeout: 10 * time.Second,
	}
	tr.TLSClientConfig = &tls.Config{
		InsecureSkipVerify: !checkCert,
	}

	return &PfAuthenticationBackend{
		url:        url,
		httpClient: &http.Client{Transport: tr},
	}
}

func (pfab *PfAuthenticationBackend) Authenticate(ctx context.Context, username, password string) (bool, *TokenInfo, error) {
	body, err := json.Marshal(map[string]string{
		"username": username,
		"password": password,
	})
	sharedutils.CheckError(err)

	req, err := http.NewRequest("POST", pfab.url.String(), bytes.NewBuffer(body))
	sharedutils.CheckError(err)
	resp, err := pfab.httpClient.Do(req)
	if err != nil {
		return false, nil, err
	}

	defer resp.Body.Close()
	reply := PfAuthenticationReply{}
	respBody, err := ioutil.ReadAll(resp.Body)
	sharedutils.CheckError(err)

	err = json.Unmarshal(respBody, &reply)
	if err != nil {
		return false, nil, err
	}

	if reply.Result != 1 {
		return false, nil, nil
	}

	ti := pfab.buildTokenInfo(ctx, &reply)

	return true, ti, nil
}

func (pfab *PfAuthenticationBackend) buildTokenInfo(ctx context.Context, data *PfAuthenticationReply) *TokenInfo {
	adminRoles := data.Roles

	adminRolesMap := make(map[string]bool)

	for _, role := range adminRoles {
		// Trim it of any leading or suffix spaces
		role = strings.Trim(role, " ")
		adminRolesMap[role] = true
	}

	return &TokenInfo{AdminRoles: adminRolesMap, TenantId: data.TenantId}
}
