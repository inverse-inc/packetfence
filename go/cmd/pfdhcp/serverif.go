package main

import (
	"context"
	"log"
	"net"
	"os"
	"syscall"

	"golang.org/x/net/ipv4"
)

type serveIfConn struct {
	ifIndex int
	conn    *ipv4.PacketConn
	cm      *ipv4.ControlMessage
}

func (s *serveIfConn) ReadFrom(b []byte) (n int, addr net.Addr, err error) {
	n, s.cm, addr, err = s.conn.ReadFrom(b)
	return
}

func (s *serveIfConn) ReadFromRaw(b []byte) (n int, cm *ipv4.ControlMessage, addr net.Addr, err error) {
	n, cm, addr, err = s.conn.ReadFrom(b)
	return
}

func (s *serveIfConn) WriteTo(b []byte, addr net.Addr) (n int, err error) {

	// ipv4 docs state that Src is "specify only", however testing by tfheen
	// shows that Src IS populated.  Therefore, to reuse the control message,
	// we set Src to nil to avoid the error "write udp4: invalid argument"

	return s.conn.WriteTo(b, s.cm, addr)
}

// ServeIf does the same job as Serve(), but listens and responds on the
// specified network interface (by index).  It also doubles as an example of
// how to leverage the dhcp4.ServeConn interface.
//
// If your target only has one interface, use Serve(). ServeIf() requires an
// import outside the std library.  Serving DHCP over multiple interfaces will
// require your own dhcp4.ServeConn, as listening to broadcasts utilises all
// interfaces (so you cannot have more than on listener).
func ServeIf(ctx context.Context, ifIndex int, p *ipv4.PacketConn, handler Handler, jobs chan job, interfaceNet *Interface) error {
	if err := p.SetControlMessage(ipv4.FlagInterface, true); err != nil {
		return err
	}
	return Serve(ctx, &serveIfConn{ifIndex: ifIndex, conn: p}, handler, jobs, interfaceNet)
}

// ListenAndServeIf listens on the UDP network address addr and then calls
// Serve with handler to handle requests on incoming packets.
// i.e. ListenAndServeIf("eth0",handler)
func ListenAndServeIf(ctx context.Context, interfaceNet *Interface, handler Handler, jobs chan job) error {
	iface, err := net.InterfaceByName(interfaceNet.Name)
	if err != nil {
		return err
	}

	p, err := broadcastOpen(net.IPv4zero, 67, interfaceNet.Name)
	if err != nil {
		return err
	}
	defer p.Close()

	return ServeIf(ctx, iface.Index, p, handler, jobs, interfaceNet)
}

func broadcastOpen(bindAddr net.IP, port int, ifname string) (*ipv4.PacketConn, error) {
	s, err := syscall.Socket(syscall.AF_INET, syscall.SOCK_DGRAM, syscall.IPPROTO_UDP)
	if err != nil {
		log.Fatal(err)
	}
	if err = syscall.SetsockoptInt(s, syscall.SOL_SOCKET, syscall.SO_REUSEADDR, 1); err != nil {
		log.Fatal(err)
	}

	if err = syscall.SetsockoptInt(s, syscall.SOL_SOCKET, syscall.SO_BROADCAST, 1); err != nil {
		log.Fatal(err)
	}
	// syscall.SetsockoptInt(s, syscall.SOL_SOCKET, syscall.SO_REUSEPORT, 1)
	if err = syscall.SetsockoptString(s, syscall.SOL_SOCKET, syscall.SO_BINDTODEVICE, ifname); err != nil {
		log.Fatal(err)
	}

	lsa := syscall.SockaddrInet4{Port: port}
	copy(lsa.Addr[:], bindAddr.To4())

	if err = syscall.Bind(s, &lsa); err != nil {
		syscall.Close(s)
		log.Fatal(err)
	}
	f := os.NewFile(uintptr(s), "")
	c, err := net.FilePacketConn(f)
	f.Close()
	if err != nil {
		log.Fatal(err)
	}
	p := ipv4.NewPacketConn(c)

	return p, nil
}

// ListenAndServeIfUnicast listens on the UDP network address addr and then calls
// Serve with handler to handle requests on incoming packets.
func ListenAndServeIfUnicast(ctx context.Context, interfaceNet *Interface, handler Handler, jobs chan job) error {

	iface, err := net.InterfaceByName(interfaceNet.Name)
	if err != nil {
		return err
	}

	p, err := UnicastOpen(interfaceNet)
	if err != nil {
		return err
	}
	defer p.Close()

	return ServeIf(ctx, iface.Index, p, handler, jobs, interfaceNet)
}

// UnicastOpen will listen on the specific port and on the specific interface.
func UnicastOpen(interfaceNet *Interface) (*ipv4.PacketConn, error) {
	s, err := syscall.Socket(syscall.AF_INET, syscall.SOCK_DGRAM, syscall.IPPROTO_UDP)
	if err != nil {
		log.Fatal(err)
	}
	if err = syscall.SetsockoptInt(s, syscall.SOL_SOCKET, syscall.SO_REUSEADDR, 1); err != nil {
		log.Fatal(err)
	}
	if interfaceNet.InterfaceType != "relay" {
		if err = syscall.SetsockoptString(s, syscall.SOL_SOCKET, syscall.SO_BINDTODEVICE, interfaceNet.Name); err != nil {
			log.Fatal(err)
		}
	}
	lsa := syscall.SockaddrInet4{Port: interfaceNet.listenPort}
	copy(lsa.Addr[:], interfaceNet.Ipv4.To4())

	if err = syscall.Bind(s, &lsa); err != nil {
		syscall.Close(s)
		log.Fatal(err)
	}
	f := os.NewFile(uintptr(s), "")
	c, err := net.FilePacketConn(f)
	f.Close()
	if err != nil {
		log.Fatal(err)
	}
	p := ipv4.NewPacketConn(c)

	return p, nil
}
