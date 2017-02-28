package firewallsso

import (
	"context"
	"fmt"
	"github.com/fingerbank/processor/log"
	"github.com/fingerbank/processor/sharedutils"
	"layeh.com/radius"
	"net"
)

type WatchGuard struct {
	FirewallSSO
	Password string `json:"password"`
	Port     string `json:"port"`
}

// Send an SSO start to the WatchGuard firewall
// Returns an error unless there is a valid reply from the firewall
func (fw *WatchGuard) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	p := fw.startRadiusPacket(ctx, info, timeout)
	client := fw.getRadiusClient(ctx)

	var err error
	client.LocalAddr, err = net.ResolveUDPAddr("udp", fw.getSourceIp(ctx).String()+":0")
	sharedutils.CheckError(err)

	_, err = client.Exchange(p, fw.PfconfigHashNS+":"+fw.Port)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Couldn't SSO to the WatchGuard, got the following error: %s", err))
		return false, err
	} else {
		return true, nil
	}
}

// Build the RADIUS packet for an SSO start
func (fw *WatchGuard) startRadiusPacket(ctx context.Context, info map[string]string, timeout int) *radius.Packet {
	r := radius.New(radius.CodeAccountingRequest, []byte(fw.Password))
	r.Set("Acct-Status-Type", uint32(1))
	r.Set("User-Name", info["username"])
	r.Set("Filter-Id", info["role"])
	r.Set("Called-Station-Id", "00:11:22:33:44:55")
	r.Set("Framed-IP-Address", net.ParseIP(info["ip"]))
	r.Set("Calling-Station-Id", info["mac"])

	return r
}

// Send an SSO stop to the WatchGuard firewall
// Returns an error unless there is a valid reply from the firewall
func (fw *WatchGuard) Stop(ctx context.Context, info map[string]string) (bool, error) {
	p := fw.stopRadiusPacket(ctx, info)
	client := fw.getRadiusClient(ctx)

	var err error
	client.LocalAddr, err = net.ResolveUDPAddr("udp", fw.getSourceIp(ctx).String()+":0")
	sharedutils.CheckError(err)

	_, err = client.Exchange(p, fw.PfconfigHashNS+":"+fw.Port)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Couldn't SSO to the WatchGuard, got the following error: %s", err))
		return false, err
	} else {
		return true, nil
	}
}

// Build the RADIUS packet for an SSO stop
func (fw *WatchGuard) stopRadiusPacket(ctx context.Context, info map[string]string) *radius.Packet {
	r := radius.New(radius.CodeAccountingRequest, []byte(fw.Password))
	r.Set("Acct-Session-Id", "acct_pf-"+info["mac"])
	r.Set("Acct-Status-Type", uint32(2))
	r.Set("User-Name", info["username"])
	r.Set("Filter-Id", info["role"])
	r.Set("Called-Station-Id", "00:11:22:33:44:55")
	r.Set("Framed-IP-Address", net.ParseIP(info["ip"]))
	r.Set("Calling-Station-Id", info["mac"])

	return r
}
