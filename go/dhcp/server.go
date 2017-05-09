package main

import (
	"net"

	dhcp "github.com/krolaw/dhcp4"
)

type Answer struct {
	D     dhcp.Packet
	IP    net.IP
	MAC   net.HardwareAddr
	Iface *net.Interface
	SrcIP net.IP
}

type Handler interface {
	ServeDHCP(req dhcp.Packet, msgType dhcp.MessageType, options dhcp.Options) Answer
}

// ServeConn is the bare minimum connection functions required by Serve()
// It allows you to create custom connections for greater control,
// such as ServeIfConn (see serverif.go), which locks to a given interface.
type ServeConn interface {
	ReadFrom(b []byte) (n int, addr net.Addr, err error)
	WriteTo(b []byte, addr net.Addr) (n int, err error)
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
func Serve(conn ServeConn, handler Handler, jobs chan job) error {

	buffer := make([]byte, 1500)

	for {

		n, addr, err := conn.ReadFrom(buffer)

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

		jobe := job{req, reqType, options, handler, addr}
		go func() {
			jobs <- jobe
		}()

	}
}

// ListenAndServe listens on the UDP network address addr and then calls
// Serve with handler to handle requests on incoming packets.
func ListenAndServe(handler Handler, jobs chan job) error {
	l, err := net.ListenPacket("udp4", ":67")
	if err != nil {
		return err
	}
	defer l.Close()
	return Serve(l, handler, jobs)
}
