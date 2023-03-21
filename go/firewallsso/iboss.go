package firewallsso

import (
	"bytes"
	"context"
	"fmt"
	"github.com/inverse-inc/go-utils/log"
	"net/http"
)

type Iboss struct {
	FirewallSSO
	NacName  string `json:"nac_name"`
	Password string `json:"password"`
	Port     string `json:"port"`
}

// Send an SSO start to the Iboss firewall
// Returns an error unless there is a valid reply from the firewall or if the HTTP request fails to be built
func (fw *Iboss) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	req, err := fw.getRequest(ctx, "login", info)

	if err != nil {
		return false, err
	}

	resp, err := fw.getHttpClient(ctx).Do(req)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting Iboss: %s", err))
		//Not returning now so that body can be closed if necessary
	}

	if resp != nil && resp.Body != nil {
		resp.Body.Close()
	}

	return err == nil, err
}

// Send an SSO stop to the Iboss firewall
// Returns an error unless there is a valid reply from the firewall or if the HTTP request fails to be built
func (fw *Iboss) Stop(ctx context.Context, info map[string]string) (bool, error) {
	req, err := fw.getRequest(ctx, "logout", info)

	if err != nil {
		return false, err
	}

	resp, err := fw.getHttpClient(ctx).Do(req)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting Iboss: %s", err))
		//Not returning now so that body can be closed if necessary
	}

	if resp != nil && resp.Body != nil {
		resp.Body.Close()
	}

	return err == nil, err
}

// Build an HTTP request to send to the Iboss firewall
// This builds the request for start+stop and is controlled by the action parameter
// This will return an error if the request cannot be built
func (fw *Iboss) getRequest(ctx context.Context, action string, info map[string]string) (*http.Request, error) {
	req, err := http.NewRequest(
		"GET",
		fmt.Sprintf(
			"http://%s:%s/nacAgent?action=%s&user=%s&dc=%s&key=%s&ip=%s&cn=%s&g=%s",
			fw.PfconfigHashNS,
			fw.Port,
			action,
			info["username"],
			fw.NacName,
			fw.Password,
			info["ip"],
			info["username"],
			info["role"],
		), bytes.NewBufferString("query=libwww-perl&mode=dist"),
	)
	req.Header.Add("Content-Type", "application/x-www-form-urlencoded")

	if err != nil {
		return nil, err
	}

	return req, nil
}
