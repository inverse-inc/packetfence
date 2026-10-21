package firewallsso

import (
	"bytes"
	"context"
	"fmt"
	"log/syslog"
	"net/url"
	"strconv"
	"text/template"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/config/pfcrypt"
)

type PaloAlto struct {
	FirewallSSO
	Transport string              `json:"transport"`
	Password  pfcrypt.CryptString `json:"password"`
	Port      string              `json:"port"`
	Vsys      string              `json:"vsys"`
}

// Firewall specific init
func (fw *PaloAlto) initChild(ctx context.Context) error {
	// Set a default value for vsys if there is none
	if fw.Vsys == "" {
		log.LoggerWContext(ctx).Debug("Setting default value for vsys as it isn't defined")
		fw.Vsys = "1"
	}
	return nil
}

// Send an SSO start to the PaloAlto using either syslog or HTTP depending on the Transport value of the struct
// This will return any value from startSyslog or startHttp depending on the type of the transport
func (fw *PaloAlto) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	if fw.Transport == "syslog" {
		log.LoggerWContext(ctx).Info("Sending SSO to PaloAlto using syslog")
		return fw.startSyslog(ctx, info, timeout)
	} else {
		log.LoggerWContext(ctx).Info("Sending SSO to PaloAlto using HTTP")
		return fw.startHttp(ctx, info, timeout)
	}
}

// Get a syslog writter connection to the PaloAlto
// This will always connect to port 514 and ignore the Port parameter
// Returns an error if it can't connect but given its UDP, this should never fail
func (fw *PaloAlto) getSyslog(ctx context.Context) (*syslog.Writer, error) {
	dst := fw.getDst(ctx, "udp", fw.PfconfigHashNS, "514")
	writer, err := syslog.Dial("udp", dst, syslog.LOG_ERR|syslog.LOG_LOCAL5, "pfsso")

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error connecting to PaloAlto: %s", err))
		return nil, err
	}

	return writer, err
}

// Send a syslog line to the PaloAlto
// Will return an error if it fails to send the message
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

// Send a start to the PaloAlto using the syslog transport
// Will return an error if it fails to send the message
func (fw *PaloAlto) startSyslog(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	if err := fw.sendSyslog(ctx, fmt.Sprintf("Group <packetfence> User <%s> Address <%s> assigned to session", info["username"], info["ip"])); err != nil {
		return false, err
	} else {
		return true, nil
	}
}

// Send a start to the PaloAlto using the HTTP transport
// Will return an error if it fails to get a valid reply from it
func (fw *PaloAlto) startHttp(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	dst := fw.getDst(ctx, "tcp", fw.PfconfigHashNS, fw.Port)
	resp, err := fw.getHttpClient(ctx).PostForm("https://"+dst+"/api/?type=user-id&vsys=vsys"+fw.Vsys+"&action=set&key="+fw.Password.String(),
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

// Get the SSO start payload for the firewall
func (fw *PaloAlto) startHttpPayload(ctx context.Context, info map[string]string, timeout int) string {
	info["timeoutsec"] = strconv.Itoa(timeout)
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
		<register-user>
			<entry user="{{.Username}}">
				<tag>
					<member timeout="{{.Timeoutsec}}">{{.Role}}</member>
				</tag>
			</entry>
		</register-user>
	</payload>
</uid-message>
`)
	b := new(bytes.Buffer)
	t.Execute(b, fw.InfoToTemplateCtx(ctx, info, timeout))
	return b.String()
}

// Send an SSO stop to the firewall if the transport mode is HTTP. Otherwise, this outputs a warning
// Will return the values from stopHttp for HTTP and no error if its syslog
func (fw *PaloAlto) Stop(ctx context.Context, info map[string]string) (bool, error) {
	if fw.Transport == "syslog" {
		log.LoggerWContext(ctx).Warn("SSO Stop isn't supported on PaloAlto when using the syslog transport. You should use the HTTP transport if you require it.")
		return false, nil
	} else {
		log.LoggerWContext(ctx).Info("Sending SSO to PaloAlto using HTTP")
		return fw.stopHttp(ctx, info)
	}
}

// Get the SSO stop payload for the firewall
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
		<unregister-user>
			<entry user="{{.Username}}">
				<tag>
					<member>{{.Role}}</member>
				</tag>
			</entry>
		</unregister-user>
	</payload>
</uid-message>
`)
	b := new(bytes.Buffer)
	t.Execute(b, fw.InfoToTemplateCtx(ctx, info, -1))
	return b.String()
}

// Send an SSO stop using HTTP to the PaloAlto firewall
// Returns an error if it fails to get a valid reply from the firewall
func (fw *PaloAlto) stopHttp(ctx context.Context, info map[string]string) (bool, error) {
	dst := fw.getDst(ctx, "tcp", fw.PfconfigHashNS, fw.Port)
	resp, err := fw.getHttpClient(ctx).PostForm("https://"+dst+"/api/?type=user-id&vsys=vsys"+fw.Vsys+"&action=set&key="+fw.Password.String(),
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
