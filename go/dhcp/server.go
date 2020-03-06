package main

import (
	"context"
	"net"

	dhcp "github.com/krolaw/dhcp4"
	"golang.org/x/net/ipv4"
)

// Answer struct
type Answer struct {
	D     dhcp.Packet
	IP    net.IP
	MAC   net.HardwareAddr
	SrcIP net.IP //Only for inline splitted network
}

// Handler interface
type Handler interface {
	ServeDHCP(ctx context.Context, req dhcp.Packet, msgType dhcp.MessageType, srcIP net.Addr, srvIP net.IP) Answer
}

// ServeConn is the bare minimum connection functions required by Serve()
// It allows you to create custom connections for greater control,
// such as ServeIfConn (see serverif.go), which locks to a given interface.
type ServeConn interface {
	ReadFrom(b []byte) (n int, addr net.Addr, err error)
	WriteTo(b []byte, addr net.Addr) (n int, err error)
	ReadFromRaw(b []byte) (n int, cm *ipv4.ControlMessage, addr net.Addr, err error)
}

// Serve takes a ServeConn (such as a net.PacketConn) that it uses for both
// reading and writing DHCP packets. Every packet is passed to the handler,
// which processes it and optionally return a response packet for writing back
// to the network.
//
// To capture limited broadcast packets (sent to 255.255.255.255), you must
// listen on a socket bound to IP_ADDRANY (0.0.0.0). This means that broadcast
// packets sent to any interface on the system may be delivered to this
// socket.  See: https://code.google.com/p/go/issues/detail?id=7106
//
// Additionally, response packets may not return to the same
// interface that the request was received from.  Writing a custom ServeConn,
// or using ServeIf() can provide a workaround to this problem.
func Serve(ctx context.Context, conn *serveIfConn, handler Handler, jobs chan job, interfaceNet *Interface) error {

	buffer := make([]byte, 1500)

	for {

		n, cm, addr, err := conn.ReadFromRaw(buffer)
		if err != nil {
			return err
		}
		if n < 240 { // Packet too small to be DHCP
			continue
		}

		req := dhcp.Packet(buffer[:n])

		if req.HLen() > 16 { // Invalid size
			continue
		}
		options := req.ParseOptions()

		var reqType dhcp.MessageType
		if t := options[dhcp.OptionDHCPMessageType]; len(t) != 1 {
			continue
		} else {
			reqType = dhcp.MessageType(t[0])
			if reqType < dhcp.Discover || reqType > dhcp.Inform {
				continue
			}
		}
		var dhcprequest dhcp.Packet
		dhcprequest = append([]byte(nil), req...)
		// addr is source ip address cm.Dst is the target
		jobe := job{DHCPpacket: dhcprequest, msgType: reqType, Int: interfaceNet, handler: handler, clientAddr: addr, srvAddr: cm.Dst, localCtx: ctx}
		go func() {
			jobs <- jobe
		}()

	}
}
