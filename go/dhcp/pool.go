package main

import (
	_ "expvar"
	"net"
	_ "net/http/pprof"

	dhcp "github.com/krolaw/dhcp4"
)

type job struct {
	p       dhcp.Packet
	msgType dhcp.MessageType
	options dhcp.Options
	handler Handler
	addr    net.Addr
}

func doWork(id int, jobe job) {
	var ans Answer
	if ans = jobe.handler.ServeDHCP(jobe.p, jobe.msgType, jobe.options); ans.D != nil {
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
