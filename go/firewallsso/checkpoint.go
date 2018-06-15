package firewallsso

import (
	"context"
	"fmt"
	"net"

	"github.com/inverse-inc/packetfence/go/log"
	"layeh.com/radius"
	"layeh.com/radius/rfc2865"
	"layeh.com/radius/rfc2866"
)

type Checkpoint struct {
	FirewallSSO
	Password string `json:"password"`
	Port     string `json:"port"`
}

// Send an SSO start to the Checkpoint firewall
// Returns an error unless there is a valid reply from the firewall
func (fw *Checkpoint) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	p := fw.startRadiusPacket(ctx, info, timeout)
	client := fw.getRadiusClient(ctx)
	// Use the background context since we don't want the lib to use our context
	ctx2, cancel := fw.RadiusContextWithTimeout()
	defer cancel()
	_, err := client.Exchange(ctx2, p, fw.PfconfigHashNS+":"+fw.Port)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Couldn't SSO to the Checkpoint, got the following error: %s", err))
		return false, err
	} else {
		return true, nil
	}
}

// Build the RADIUS packet for an SSO start
func (fw *Checkpoint) startRadiusPacket(ctx context.Context, info map[string]string, timeout int) *radius.Packet {
	r := radius.New(radius.CodeAccountingRequest, []byte(fw.Password))
	rfc2866.AcctStatusType_Add(r, rfc2866.AcctStatusType_Value_Start)
	rfc2866.AcctSessionID_AddString(r, "acct_pf-"+info["mac"])
	rfc2865.UserName_AddString(r, info["username"])
	rfc2865.SessionTimeout_Add(r, rfc2865.SessionTimeout(timeout))
	rfc2865.CalledStationID_AddString(r, "00:11:22:33:44:55")
	rfc2865.FramedIPAddress_Add(r, net.ParseIP(info["ip"]))
	rfc2865.CallingStationID_AddString(r, info["mac"])

	return r
}

// SSO stop handler which does nothing other than printing a warning since the SSO stop is unimplemented for this firewall
func (fw *Checkpoint) Stop(ctx context.Context, info map[string]string) (bool, error) {
	log.LoggerWContext(ctx).Warn("SSO Stop is not available for this firewall")
	return false, nil
}
