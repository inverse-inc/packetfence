package firewallsso

import (
	"context"
	"fmt"
	"net/http"

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

// Send a start to the PaloAlto using the HTTP transport
// Will return an error if it fails to get a valid reply from it
func (fw *JuniperSRX) startHttp(ctx context.Context, info map[string]string, timeout int) (bool, error) {

	req, err := http.NewRequest("GET", "https://"+fw.PfconfigHashNS+":"+fw.Port+"/rpc/request-userfw-local-auth-table-add?user-name="+info["username"]+"&ip-address="+info["ip"]+"&roles="+info["role"], nil)
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

// Send an SSO stop to the firewall by using HTTP transport.
func (fw *JuniperSRX) Stop(ctx context.Context, info map[string]string) (bool, error) {
	log.LoggerWContext(ctx).Info("Sending SSO to JuniperSRX using HTTP")
	return fw.stopHttp(ctx, info)

}

// Send an SSO stop using HTTP to the JuniperSRX firewall
// Returns an error if it fails to get a valid reply from the firewall
func (fw *JuniperSRX) stopHttp(ctx context.Context, info map[string]string) (bool, error) {

	req, err := http.NewRequest("GET", "https://"+fw.PfconfigHashNS+":"+fw.Port+"/rpc/request-userfw-local-auth-table-delete-user?user-name="+info["username"], nil)
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
