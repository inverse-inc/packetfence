package firewallsso

import (
	"bytes"
	"context"
	"fmt"
	"github.com/fingerbank/processor/log"
	"net/http"
	"net/url"
	"text/template"
)

type PaloAlto struct {
	FirewallSSO
	Transport string `json:"transport"`
	Password  string `json:"password"`
	Port      string `json:"port"`
}

func (fw *PaloAlto) Start(ctx context.Context, info map[string]string, timeout int) bool {
	if fw.Transport == "syslog" {
		//TODO: implement this
		//return fw.startSyslog(ctx, info, timeout)
	} else {
		log.LoggerWContext(ctx).Info("Sending SSO to PaloAlto using HTTP")
		return fw.startHttp(ctx, info, timeout)
	}
	return false
}

func (fw *PaloAlto) startHttp(ctx context.Context, info map[string]string, timeout int) bool {
	//TODO: change back to https when done testing
	_, err := http.PostForm("http://"+fw.PfconfigHashNS+":"+fw.Port+"/api/?type=user-id&action=set&key="+fw.Password,
		url.Values{"cmd": {fw.startHttpPayload(ctx, info, timeout)}})

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting PaloAlto: %s", err))
	}

	return err != nil
}

func (fw *PaloAlto) startHttpPayload(ctx context.Context, info map[string]string, timeout int) string {
	// PaloAlto XML API expects the timeout in minutes
	timeout = timeout / 60
	t := template.New("PaloAlto.startHttp")
	t.Parse(`
<uid-message>
		<version>1.0</version>
		<type>update</type>
		<payload>
				<login>
						<entry name="{{.Username}}" ip="{{.Ip}}" timeout="{{.Timeout}}"/>
				</login>
		</payload>
</uid-message>
`)
	b := new(bytes.Buffer)
	t.Execute(b, fw.InfoToTemplateCtx(ctx, info, timeout))
	return b.String()
}

func (fw *PaloAlto) Stop(ctx context.Context, info map[string]string) bool {
	if fw.Transport == "syslog" {
		//TODO: implement this...
		//return fw.stopSyslog(ctx, info, timeout)
	} else {
		log.LoggerWContext(ctx).Info("Sending SSO to PaloAlto using HTTP")
		return fw.stopHttp(ctx, info)
	}
	return false
}

func (fw *PaloAlto) stopHttpPayload(ctx context.Context, info map[string]string) string {
	t := template.New("PaloAlto.stopHttp")
	t.Parse(`
<uid-message>
		<version>1.0</version>
		<type>update</type>
		<payload>
				<logout>
						<entry name="{{.Username}}" ip="{{.Ip}}"/>
				</logout>
		</payload>
</uid-message>
`)
	b := new(bytes.Buffer)
	t.Execute(b, fw.InfoToTemplateCtx(ctx, info, -1))
	return b.String()
}

func (fw *PaloAlto) stopHttp(ctx context.Context, info map[string]string) bool {
	//TODO: change back to https when done testing
	//TODO: Ignore cert checks
	_, err := http.PostForm("http://"+fw.PfconfigHashNS+":"+fw.Port+"/api/?type=user-id&action=set&key="+fw.Password,
		url.Values{"cmd": {fw.stopHttpPayload(ctx, info)}})

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting PaloAlto: %s", err))
	}

	return err != nil
}
