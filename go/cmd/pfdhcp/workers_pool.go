package main

import (
	"context"
	_ "expvar"
	"net"
	"strconv"

	dhcp "github.com/inverse-inc/dhcp4"
	"github.com/inverse-inc/go-utils/log"
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
		ctx = log.AddToLogContext(ctx, "mac", ans.MAC.String())
		log.LoggerWContext(ctx).Debug("Giaddr " + element.DHCPpacket.GIAddr().String())

		// If giaddr is 0.0.0.0 and source ip is 0.0.0.0 (broadcast)
		if element.DHCPpacket.GIAddr().Equal(net.IPv4zero) && net.ParseIP(ipStr).Equal(net.IPv4zero) {
			log.LoggerWContext(ctx).Debug("Broadcast")
			client, _ := NewRawClient(element.Int.intNet)
			client.sendDHCP(ans.MAC, ans.D, ans.IP, element.Int.Ipv4)
			client.Close()
		} else {
			// Non broadcast
			dstPort, _ := strconv.Atoi(portStr)
			// If the source ip is equal to the giaddr then send it to the source ip
			if net.ParseIP(ipStr).Equal(element.DHCPpacket.GIAddr()) {
				log.LoggerWContext(ctx).Debug("L3 coming from the dhcp relay " + element.DHCPpacket.GIAddr().String())
				sendUnicastDHCP(ans.D, ans.SrcIP, net.ParseIP(ipStr), bootpServer, dstPort)
			} else {
				// Probably L2
				if element.DHCPpacket.GIAddr().Equal(net.IPv4zero) {
					log.LoggerWContext(ctx).Debug("L2 - no giaddr, send it to " + ipStr)
					sendUnicastDHCP(ans.D, ans.SrcIP, net.ParseIP(ipStr), bootpServer, dstPort)
				} else {
					if ans.DstIP == "giaddr" {
						log.LoggerWContext(ctx).Debug("L3 - reply to giaddr " + element.DHCPpacket.GIAddr().String())
						sendUnicastDHCP(ans.D, ans.SrcIP, element.DHCPpacket.GIAddr(), bootpServer, dstPort)
					} else {
						log.LoggerWContext(ctx).Debug("L3 - sent to source IP" + ipStr)
						sendUnicastDHCP(ans.D, ans.SrcIP, net.ParseIP(ipStr), bootpServer, dstPort)
					}
				}
			}
		}
	}
}
