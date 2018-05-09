package main

import (
	_ "expvar"
	"net"

	"github.com/inverse-inc/packetfence/go/log"
	dhcp "github.com/krolaw/dhcp4"
)

type job struct {
	p       dhcp.Packet
	msgType dhcp.MessageType
	handler Handler
	addr    net.Addr
}

func doWork(id int, jobe job) {
	var ans Answer
	localCtx := log.LoggerNewRequest(ctx)
	if ans = jobe.handler.ServeDHCP(localCtx, jobe.p, jobe.msgType); ans.D != nil {
		ipStr, _, _ := net.SplitHostPort(jobe.addr.String())
		if !(jobe.p.GIAddr().Equal(net.IPv4zero) && net.ParseIP(ipStr).Equal(net.IPv4zero)) {
			sendUnicastDHCP(ans.D, jobe.addr, ans.SrcIP)
		} else {
			client, _ := NewRawClient(ans.Iface)
			client.sendDHCP(ans.MAC, ans.D, ans.IP, ans.SrcIP)
			client.Close()
		}
	}
}
