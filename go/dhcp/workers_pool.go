package main

import (
	"context"
	_ "expvar"
	"net"
	"strconv"

	dhcp "github.com/krolaw/dhcp4"
)

type job struct {
	DHCPpacket dhcp.Packet
	msgType    dhcp.MessageType
	Int        *Interface
	handler    Handler
	clientAddr net.Addr //remote client ip
	srvAddr    net.IP
	localCtx   context.Context
}

func doWork(id int, element job) {
	var ans Answer
	if ans = element.handler.ServeDHCP(element.localCtx, element.DHCPpacket, element.msgType, element.clientAddr, element.srvAddr); ans.D != nil {
		ipStr, portStr, _ := net.SplitHostPort(element.clientAddr.String())
		if !(element.DHCPpacket.GIAddr().Equal(net.IPv4zero) && net.ParseIP(ipStr).Equal(net.IPv4zero)) {
			dstPort, _ := strconv.Atoi(portStr)

			if !(net.ParseIP(ipStr).Equal(element.DHCPpacket.GIAddr())) {
				if !(element.DHCPpacket.GIAddr().Equal(net.IPv4zero)) {
					sendUnicastDHCP(ans.D, ans.SrcIP, element.DHCPpacket.GIAddr(), bootpServer, dstPort)
				}
			}
			sendUnicastDHCP(ans.D, ans.SrcIP, net.ParseIP(ipStr), bootpServer, dstPort)
		} else {
			client, _ := NewRawClient(element.Int.intNet)
			client.sendDHCP(ans.MAC, ans.D, ans.IP, element.Int.Ipv4)
			client.Close()
		}
	}
}
