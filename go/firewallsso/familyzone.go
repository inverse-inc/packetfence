package firewallsso

import (
	"bytes"
	"context"
	"fmt"
	"github.com/inverse-inc/packetfence/go/log"
	"net/url"
	"text/template"
)

type FamilyZone struct {
	FirewallSSO
	Username string `json:"username"`
	Password string `json:"password"`
	Port     string `json:"port"`
	Region   string `json:"region"`
}

// Firewall specific init
func (fw *FamilyZone) initChild(ctx context.Context) error {
	// Set a default value for vsys if there is none
	if fw.Region == "" {
		log.LoggerWContext(ctx).Debug("Setting default value for Region as it isn't defined")
		fw.Region = "syd-1"
	}
	return nil
}

// Send an SSO start to the FamilyZone using either syslog or HTTP depending on the Transport value of the struct
// This will return any value from startSyslog or startHttp depending on the type of the transport
func (fw *FamilyZone) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	log.LoggerWContext(ctx).Info("Sending SSO to FamilyZone using HTTP")
	return fw.startHttp(ctx, info, timeout)
}

// Send a start to the FamilyZone using the HTTP transport
// Will return an error if it fails to get a valid reply from it
func (fw *FamilyZone) startHttp(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	resp, err := fw.getHttpClient(ctx).PostForm("https://"+fw.PfconfigHashNS+":"+fw.Port+"/api/?type=user-id&vsys=vsys"+fw.Region+"&action=set&key="+fw.Password,
		url.Values{"cmd": {fw.startHttpPayload(ctx, info, timeout)}})

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting FamilyZone: %s", err))
		//Not returning now so that body closes below
	}

	if resp != nil && resp.Body != nil {
		resp.Body.Close()
	}

	return err == nil, err
}

// Get the SSO start payload for the firewall
func (fw *FamilyZone) startHttpPayload(ctx context.Context, info map[string]string, timeout int) string {
	// FamilyZone XML API expects the timeout in minutes
	timeout = timeout / 60
	t := template.New("FamilyZone")
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

// Send an SSO stop to the firewall if the transport mode is HTTP. Otherwise, this outputs a warning
// Will return the values from stopHttp for HTTP and no error if its syslog
func (fw *FamilyZone) Stop(ctx context.Context, info map[string]string) (bool, error) {
	log.LoggerWContext(ctx).Info("Sending SSO to FamilyZone using HTTP")
	return fw.stopHttp(ctx, info)
}

// Get the SSO stop payload for the firewall
func (fw *FamilyZone) stopHttpPayload(ctx context.Context, info map[string]string) string {
	t := template.New("FamilyZone.stopHttp")
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

// Send an SSO stop using HTTP to the FamilyZone firewall
// Returns an error if it fails to get a valid reply from the firewall
func (fw *FamilyZone) stopHttp(ctx context.Context, info map[string]string) (bool, error) {
	resp, err := fw.getHttpClient(ctx).PostForm("https://"+fw.PfconfigHashNS+":"+fw.Port+"/api/?type=user-id&vsys=vsys"+fw.Region+"&action=set&key="+fw.Password,
		url.Values{"cmd": {fw.stopHttpPayload(ctx, info)}})

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error contacting FamilyZone: %s", err))
		//Not returning now so that body closes below
	}

	if resp != nil && resp.Body != nil {
		resp.Body.Close()
	}
	return err == nil, err
}
