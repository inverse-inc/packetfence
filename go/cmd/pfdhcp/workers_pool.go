package main

import (
	"context"
	"database/sql"
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
	db         *sql.DB
}

func doWork(id int, element job) {
	var ans Answer
	if ans = element.handler.ServeDHCP(element.localCtx, element.DHCPpacket, element.msgType, element.clientAddr, element.srvAddr, element.db); ans.D != nil {
		ipStr, portStr, err := net.SplitHostPort(element.clientAddr.String())
		if err != nil {
			log.LoggerWContext(ctx).Error("Failed to split host:port from client address: " + err.Error() + " mac=" + ans.MAC.String())
			return
		}
		// ctx = log.AddToLogContext(ctx, "mac", ans.MAC.String())
		log.LoggerWContext(ctx).Debug("Giaddr " + element.DHCPpacket.GIAddr().String() + " mac=" + ans.MAC.String())

		// If giaddr is 0.0.0.0 and source ip is 0.0.0.0 (broadcast)
		if element.DHCPpacket.GIAddr().Equal(net.IPv4zero) && net.ParseIP(ipStr).Equal(net.IPv4zero) {
			log.LoggerWContext(ctx).Debug("Broadcast" + " mac=" + ans.MAC.String())
			client, err := NewRawClient(element.Int.intNet)
			if err != nil {
				log.LoggerWContext(ctx).Error("Failed to create raw client: " + err.Error() + " mac=" + ans.MAC.String())
				return
			}
			client.sendDHCP(ans.MAC, ans.D, ans.IP, element.Int.Ipv4)
			client.Close()
		} else {
			// Non broadcast
			dstPort, err := strconv.Atoi(portStr)
			if err != nil {
				log.LoggerWContext(ctx).Error("Failed to parse port number: " + err.Error() + " mac=" + ans.MAC.String())
				return
			}
			// If the source ip is equal to the giaddr then send it to the source ip
			if net.ParseIP(ipStr).Equal(element.DHCPpacket.GIAddr()) {
				log.LoggerWContext(ctx).Debug("L3 coming from the dhcp relay " + element.DHCPpacket.GIAddr().String() + " mac=" + ans.MAC.String())
				sendUnicastDHCP(ans.D, ans.SrcIP, net.ParseIP(ipStr), bootpServer, dstPort)
			} else {
				// Probably L2
				if element.DHCPpacket.GIAddr().Equal(net.IPv4zero) {
					log.LoggerWContext(ctx).Debug("L2 - no giaddr, send it to " + ipStr + " mac=" + ans.MAC.String())
					sendUnicastDHCP(ans.D, ans.SrcIP, net.ParseIP(ipStr), bootpServer, dstPort)
				} else {
					if ans.DstIP == "giaddr" {
						log.LoggerWContext(ctx).Debug("L3 - reply to giaddr " + element.DHCPpacket.GIAddr().String() + " mac=" + ans.MAC.String())
						sendUnicastDHCP(ans.D, ans.SrcIP, element.DHCPpacket.GIAddr(), bootpServer, dstPort)
					} else {
						log.LoggerWContext(ctx).Debug("L3 - sent to source IP" + ipStr + " mac=" + ans.MAC.String())
						sendUnicastDHCP(ans.D, ans.SrcIP, net.ParseIP(ipStr), bootpServer, dstPort)
					}
				}
			}
		}
	}
}
