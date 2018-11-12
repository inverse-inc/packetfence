package main

import (
	"context"
	_ "expvar"
	"net"
)

type job struct {
	p        dhcp.Packet
	msgType  dhcp.MessageType
	handler  Handler
	addr     net.Addr
	dst      net.IP
	localCtx context.Context
}

func doWork(id int, jobe job) {
	var ans Answer
	if ans = jobe.handler.ServeDHCP(jobe.localCtx, jobe.p, jobe.msgType); ans.D != nil {
		ipStr, _, _ := net.SplitHostPort(jobe.addr.String())
		if !(jobe.p.GIAddr().Equal(net.IPv4zero) && net.ParseIP(ipStr).Equal(net.IPv4zero)) {
			sendUnicastDHCP(ans.D, jobe.addr, jobe.dst, jobe.p.GIAddr(), true)
		} else {
			client, _ := NewRawClient(ans.Iface)
			client.sendDHCP(ans.MAC, ans.D, ans.IP, ans.SrcIP)
			client.Close()
		}
	}
}
