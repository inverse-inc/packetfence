package firewallsso

import (
	"context"
	"fmt"
	"github.com/fingerbank/processor/log"
	"layeh.com/radius"
	"net"
)

type FortiGate struct {
	FirewallSSO
	Password string `json:"password"`
	Port     string `json:"port"`
}

func (fw *FortiGate) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	p := fw.startRadiusPacket(ctx, info, timeout)
	client := fw.getRadiusClient(ctx)
	_, err := client.Exchange(p, fw.PfconfigHashNS+":"+fw.Port)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Couldn't SSO to the fortigate, got the following error: %s", err))
		return false, err
	} else {
		return true, nil
	}
}

func (fw *FortiGate) startRadiusPacket(ctx context.Context, info map[string]string, timeout int) *radius.Packet {
	r := radius.New(radius.CodeAccountingRequest, []byte(fw.Password))
	r.Set("Acct-Status-Type", uint32(1))
	r.Set("User-Name", info["username"])
	r.Set("Class", info["role"])
	r.Set("Called-Station-Id", "00:11:22:33:44:55")
	r.Set("Framed-IP-Address", net.ParseIP(info["ip"]))
	r.Set("Calling-Station-Id", info["mac"])

	return r
}

func (fw *FortiGate) Stop(ctx context.Context, info map[string]string) (bool, error) {
	p := fw.stopRadiusPacket(ctx, info)
	client := fw.getRadiusClient(ctx)
	_, err := client.Exchange(p, fw.PfconfigHashNS+":"+fw.Port)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Couldn't SSO to the fortigate, got the following error: %s", err))
		return false, err
	} else {
		return true, nil
	}
}

func (fw *FortiGate) stopRadiusPacket(ctx context.Context, info map[string]string) *radius.Packet {
	r := radius.New(radius.CodeAccountingRequest, []byte(fw.Password))
	r.Set("Acct-Session-Id", "acct_pf-"+info["mac"])
	r.Set("Acct-Status-Type", uint32(2))
	r.Set("User-Name", info["username"])
	r.Set("Class", info["role"])
	r.Set("Called-Station-Id", "00:11:22:33:44:55")
	r.Set("Framed-IP-Address", net.ParseIP(info["ip"]))
	r.Set("Calling-Station-Id", info["mac"])

	return r
}
