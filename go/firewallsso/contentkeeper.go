package firewallsso

import (
	"context"
	"fmt"
	"net"

	"time"

	radius "github.com/inverse-inc/go-radius"
	"github.com/inverse-inc/go-radius/rfc2865"
	"github.com/inverse-inc/go-radius/rfc2866"
	"github.com/inverse-inc/go-radius/rfc2869"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
)

type ContentKeeper struct {
	FirewallSSO
	Password string `json:"password"`
	Port     string `json:"port"`
}

// Send an SSO start to the ContentKeeper firewall
// Returns an error unless there is a valid reply from the firewall
func (fw *ContentKeeper) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	p := fw.startRadiusPacket(ctx, info, timeout)
	client := fw.getRadiusClient(ctx)

	var err error
	client.Dialer.LocalAddr, err = net.ResolveUDPAddr("udp", fw.getSourceIp(ctx).String()+":0")
	sharedutils.CheckError(err)

	// Use the background context since we don't want the lib to use our context
	ctx2, cancel := fw.RadiusContextWithTimeout()
	defer cancel()
	_, err = client.Exchange(ctx2, p, fw.PfconfigHashNS+":"+fw.Port)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Couldn't SSO to the ContentKeeper, got the following error: %s", err))
		return false, err
	} else {
		return true, nil
	}
}

// Build the RADIUS packet for an SSO start
func (fw *ContentKeeper) startRadiusPacket(ctx context.Context, info map[string]string, timeout int) *radius.Packet {
	r := radius.New(radius.CodeAccountingRequest, []byte(fw.Password))
	rfc2866.AcctStatusType_Add(r, rfc2866.AcctStatusType_Value_Start)
	rfc2865.UserName_AddString(r, info["username"])
	rfc2865.CalledStationID_AddString(r, "00:11:22:33:44:55")
	rfc2865.FramedIPAddress_Add(r, net.ParseIP(info["ip"]))
	rfc2865.CallingStationID_AddString(r, info["mac"])
	rfc2869.EventTimestamp_Add(r, time.Now())

	return r
}

// Send an SSO stop to the ContentKeeper firewall
// Returns an error unless there is a valid reply from the firewall
func (fw *ContentKeeper) Stop(ctx context.Context, info map[string]string) (bool, error) {
	log.LoggerWContext(ctx).Info("Not supported sending SSO to ContentKeeper using RADIUS")
	return true, nil
}
