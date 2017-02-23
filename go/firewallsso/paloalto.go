package firewallsso

import (
	"bytes"
	"context"
	"fmt"
	"github.com/fingerbank/processor/log"
	"log/syslog"
	"net/url"
	"text/template"
)

type PaloAlto struct {
	FirewallSSO
	Transport string `json:"transport"`
	Password  string `json:"password"`
	Port      string `json:"port"`
}

func (fw *PaloAlto) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	if fw.Transport == "syslog" {
		return fw.startSyslog(ctx, info, timeout)
	} else {
		log.LoggerWContext(ctx).Info("Sending SSO to PaloAlto using HTTP")
		return fw.startHttp(ctx, info, timeout)
	}
}

func (fw *PaloAlto) getSyslog(ctx context.Context) (*syslog.Writer, error) {
	writer, err := syslog.Dial("udp", fw.PfconfigHashNS+":514", syslog.LOG_ERR|syslog.LOG_LOCAL5, "pfsso")

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error connecting to PaloAlto: %s", err))
		return nil, err
	}

	return writer, err
}

func (fw *PaloAlto) sendSyslog(ctx context.Context, line string) error {
	writer, err := fw.getSyslog(ctx)

	if err != nil {
		return err
	}

	err = writer.Err(line)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error sending message to PaloAlto: %s", err))
		return err
	}

	return nil
}

func (fw *PaloAlto) startSyslog(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	if err := fw.sendSyslog(ctx, fmt.Sprintf("Group <packetfence> User <%s> Address <%s> assigned to session", info["username"], info["ip"])); err != nil {
		return false, err
	} else {
		return true, nil
	}
}

func (fw *PaloAlto) startHttp(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	resp, err := fw.getHttpClient(ctx).PostForm("https://"+fw.PfconfigHashNS+":"+fw.Port+"/api/?type=user-id&action=set&key="+fw.Password,
		url.Values{"cmd": {fw.startHttpPayload(ctx, info, timeout)}})

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting PaloAlto: %s", err))
		//Not returning now so that body closes below
	}

	if resp != nil && resp.Body != nil {
		resp.Body.Close()
	}

	return err == nil, err
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

func (fw *PaloAlto) Stop(ctx context.Context, info map[string]string) (bool, error) {
	if fw.Transport == "syslog" {
		log.LoggerWContext(ctx).Info("SSO Stop isn't supported on PaloAlto when using the syslog transport. You should use the HTTP transport if you require it.")
		return false, nil
	} else {
		log.LoggerWContext(ctx).Info("Sending SSO to PaloAlto using HTTP")
		return fw.stopHttp(ctx, info)
	}
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

func (fw *PaloAlto) stopHttp(ctx context.Context, info map[string]string) (bool, error) {
	resp, err := fw.getHttpClient(ctx).PostForm("https://"+fw.PfconfigHashNS+":"+fw.Port+"/api/?type=user-id&action=set&key="+fw.Password,
		url.Values{"cmd": {fw.stopHttpPayload(ctx, info)}})

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting PaloAlto: %s", err))
		//Not returning now so that body closes below
	}

	if resp != nil && resp.Body != nil {
		resp.Body.Close()
	}
	return err == nil, err
}
