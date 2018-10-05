package firewallsso

import (
	"bytes"
	"context"
	"fmt"
	"net/http"
	"text/template"
	"time"

	"github.com/inverse-inc/packetfence/go/log"
)

type JuniperSRX struct {
	FirewallSSO
	Username string `json:"username"`
	Password string `json:"password"`
	Port     string `json:"port"`
}

// Send an SSO start to the JuniperSRX using HTTP
// This will return any value from startSyslog or startHttp depending on the type of the transport
func (fw *JuniperSRX) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	log.LoggerWContext(ctx).Info("Sending SSO to JuniperSRX using HTTP")
	return fw.startHttp(ctx, info, timeout)

}

// Send a start to the JuniperSRX using the HTTP transport
// Will return an error if it fails to get a valid reply from it
func (fw *JuniperSRX) startHttp(ctx context.Context, info map[string]string, timeout int) (bool, error) {

	req, err := http.NewRequest("POST", "https://"+fw.PfconfigHashNS+":"+fw.Port+"/api/userfw/v1/post-entry", bytes.NewBuffer([]byte(fw.startHttpPayload(ctx, info))))
	req.SetBasicAuth(fw.Username, fw.Password)
	client := fw.getHttpClient(ctx)
	resp, err := client.Do(req)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting JuniperSRX: %s", err))
		//Not returning now so that body closes below
	}

	if resp != nil && resp.Body != nil {
		resp.Body.Close()
	}

	return err == nil, err
}

func (fw *JuniperSRX) startHttpPayload(ctx context.Context, info map[string]string) string {
	info["Time"] = time.Now().Format(time.RFC3339)
	t := template.New("JuniperSRX.startHttp")
	t.Parse(`<?xml version="1.0"?>
		<userfw-entries>
			<userfw-entry>
				<source>PacketFence</source>
				<timestamp>{{.Time}}</timestamp>
				<operation>logon</operation>
				<IP>{{.Ip}}</IP>
				<domain>{{.Realm}}</domain>
				<user>{{.Username}}</user>
				<role-list>
					<role>{{.Role}}</role>
				</role-list>
				<posture>Healthy</posture>
				<end-user-attribute>
					<device-identity>
						<value>{{.Computername}}</value>
						<groups>
							<group>{{.Role}}</group>
						</groups>
					</device-identity>
					<device-category>{{.Device_class}}</device-category>
					<device-os>{{.Device_type}}</device-os>
					<device-os-version>"{{.Device_version}}"</device-os-version>
				</end-user-attribute>
			</userfw-entry>
		</userfw-entries>`)

	b := new(bytes.Buffer)
	t.Execute(b, fw.InfoToTemplateCtx(ctx, info, 0))
	return b.String()
}

func (fw *JuniperSRX) stopHttpPayload(ctx context.Context, info map[string]string) string {
	info["Time"] = time.Now().UTC().Format(time.RFC3339)
	t := template.New("JuniperSRX.startHttp")
	t.Parse(`<?xml version="1.0"?>
		<userfw-entries>
			<userfw-entry>
				<source>PacketFence</source>
				<timestamp>{{.Time}}</timestamp>
				<operation>logoff</operation>
				<IP>{{.Ip}}</IP>
			</userfw-entry>
		</userfw-entries>`)
	b := new(bytes.Buffer)
	t.Execute(b, fw.InfoToTemplateCtx(ctx, info, 0))
	return b.String()
}

// Send an SSO stop to the firewall by using HTTP transport.
func (fw *JuniperSRX) Stop(ctx context.Context, info map[string]string) (bool, error) {
	log.LoggerWContext(ctx).Info("Sending SSO to JuniperSRX using HTTP")
	return fw.stopHttp(ctx, info)

}

// Send an SSO stop using HTTP to the JuniperSRX firewall
// Returns an error if it fails to get a valid reply from the firewall
func (fw *JuniperSRX) stopHttp(ctx context.Context, info map[string]string) (bool, error) {

	req, err := http.NewRequest("POST", "https://"+fw.PfconfigHashNS+":"+fw.Port+"/api/userfw/v1/post-entry", bytes.NewBuffer([]byte(fw.stopHttpPayload(ctx, info))))
	req.SetBasicAuth(fw.Username, fw.Password)
	client := fw.getHttpClient(ctx)
	resp, err := client.Do(req)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting JuniperSRX: %s", err))
		//Not returning now so that body closes below
	}

	if resp != nil && resp.Body != nil {
		resp.Body.Close()
	}

	return err == nil, err
}
