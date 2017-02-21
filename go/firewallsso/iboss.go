package firewallsso

import (
	"bytes"
	"context"
	"fmt"
	"github.com/fingerbank/processor/log"
	"github.com/fingerbank/processor/sharedutils"
	"net/http"
)

type Iboss struct {
	FirewallSSO
	NacName  string `json:"nac_name"`
	Password string `json:"password"`
	Port     string `json:"port"`
}

func (fw *Iboss) Start(ctx context.Context, info map[string]string, timeout int) bool {
	req := fw.getRequest(ctx, "login", info)
	resp, err := http.DefaultClient.Do(req)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting Iboss: %s", err))
	}

	if resp != nil && resp.Body != nil {
		resp.Body.Close()
	}

	return err == nil
}

func (fw *Iboss) Stop(ctx context.Context, info map[string]string) bool {
	req := fw.getRequest(ctx, "logout", info)
	resp, err := http.DefaultClient.Do(req)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting Iboss: %s", err))
	}

	if resp != nil && resp.Body != nil {
		resp.Body.Close()
	}

	return err == nil
}

func (fw *Iboss) getRequest(ctx context.Context, action string, info map[string]string) *http.Request {
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
	sharedutils.CheckError(err)

	return req
}
