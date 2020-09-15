package main

import (
	"bytes"
	"encoding/binary"
	"log"
	"net"
	"os"

	"syscall"

	"github.com/mdlayher/ethernet"
	"github.com/mdlayher/raw"
)

// A RawClient is a Wake-on-LAN client which operates directly on top of
// Ethernet frames using raw sockets.  It can be used to send WoL magic packets
// to other machines on a local network, using their hardware addresses.
type RawClient struct {
	ifi *net.Interface
	p   net.PacketConn
}

type udphdr struct {
	src  uint16
	dst  uint16
	ulen uint16
	csum uint16
}

type pseudohdr struct {
	ipsrc   [4]byte
	ipdst   [4]byte
	zero    uint8
	ipproto uint8
	plen    uint16
}

type iphdr struct {
	vhl   uint8
	tos   uint8
	iplen uint16
	id    uint16
	off   uint16
	ttl   uint8
	proto uint8
	csum  uint16
	src   [4]byte
	dst   [4]byte
}

// NewRawClient creates a new RawClient using the specified network interface.
//
// Note that raw sockets typically require elevated user privileges, such as
// the 'root' user on Linux, or the 'SET_CAP_RAW' capability.
//
// For this reason, it is typically recommended to use the regular Client type
// instead, which operates over UDP.
func NewRawClient(ifi *net.Interface) (*RawClient, error) {
	// Open raw socket to send Wake-on-LAN magic packets
	var cfg raw.Config

	p, err := raw.ListenPacket(ifi, 0x0806, &cfg)
	if err != nil {
		return nil, err
	}

	return &RawClient{
		ifi: ifi,
		p:   p,
	}, nil
}

// Close closes a RawClient's raw socket.
func (c *RawClient) Close() error {
	return c.p.Close()
}

// sendDHCP create a udp packet and stores it in an
// Ethernet frame, and sends the frame over a raw socket to attempt to wake
// a machine.
func (c *RawClient) sendDHCP(target net.HardwareAddr, dhcp []byte, dstIP net.IP, srcIP net.IP) error {

	proto := 17

	udpsrc := uint(67)
	udpdst := uint(68)

	udp := udphdr{
		src: uint16(udpsrc),
		dst: uint16(udpdst),
	}

	udplen := 8 + len(dhcp)

	ip := iphdr{
		vhl:   0x45,
		tos:   0,
		id:    0x0000, // the kernel overwrites id if it is zero
		off:   0,
		ttl:   128,
		proto: uint8(proto),
	}
	copy(ip.src[:], srcIP.To4())
	copy(ip.dst[:], dstIP.To4())

	udp.ulen = uint16(udplen)
	udp.checksum(&ip, dhcp)

	totalLen := 20 + udplen

	ip.iplen = uint16(totalLen)
	ip.checksum()

	buf := bytes.NewBuffer([]byte{})
	err := binary.Write(buf, binary.BigEndian, &udp)
	if err != nil {
		log.Fatal(err)
	}

	udpHeader := buf.Bytes()
	dataWithHeader := append(udpHeader, dhcp...)

	buff := bytes.NewBuffer([]byte{})
	err = binary.Write(buff, binary.BigEndian, &ip)
	if err != nil {
		log.Fatal(err)
	}

	ipHeader := buff.Bytes()
	packet := append(ipHeader, dataWithHeader...)

	// Create Ethernet frame
	f := &ethernet.Frame{
		Destination: target,
		Source:      c.ifi.HardwareAddr,
		EtherType:   ethernet.EtherTypeIPv4,
		Payload:     packet,
	}
	fb, err := f.MarshalBinary()
	if err != nil {
		return err
	}

	// Send packet to target
	_, err = c.p.WriteTo(fb, &raw.Addr{
		HardwareAddr: target,
	})
	return err
}

func (u *udphdr) checksum(ip *iphdr, payload []byte) {
	u.csum = 0

	phdr := pseudohdr{
		ipsrc:   ip.src,
		ipdst:   ip.dst,
		zero:    0,
		ipproto: ip.proto,
		plen:    u.ulen,
	}
	var b bytes.Buffer
	binary.Write(&b, binary.BigEndian, &phdr)
	binary.Write(&b, binary.BigEndian, u)
	binary.Write(&b, binary.BigEndian, &payload)
	u.csum = checksum(b.Bytes())
}

func checksum(buf []byte) uint16 {
	sum := uint32(0)

	for ; len(buf) >= 2; buf = buf[2:] {
		sum += uint32(buf[0])<<8 | uint32(buf[1])
	}
	if len(buf) > 0 {
		sum += uint32(buf[0]) << 8
	}
	for sum > 0xffff {
		sum = (sum >> 16) + (sum & 0xffff)
	}
	csum := ^uint16(sum)
	/*
	 * From RFC 768:
	 * If the computed checksum is zero, it is transmitted as all ones (the
	 * equivalent in one's complement arithmetic). An all zero transmitted
	 * checksum value means that the transmitter generated no checksum (for
	 * debugging or for higher level protocols that don't care).
	 */
	if csum == 0 {
		csum = 0xffff
	}
	return csum
}

func (h *iphdr) checksum() {
	h.csum = 0
	var b bytes.Buffer
	binary.Write(&b, binary.BigEndian, h)
	h.csum = checksum(b.Bytes())
}

// sendUnicastDHCP create a udp packet and stores it in an
// Ethernet frame, and sends the frame over a raw socket to attempt to wake
// a machine.
func sendUnicastDHCP(dhcp []byte, srcIP net.IP, dstIP net.IP, udpsrc int, udpdst int) error {

	s, err := syscall.Socket(syscall.AF_INET, syscall.SOCK_RAW, syscall.IPPROTO_RAW)
	if err != nil {
		log.Fatal(err)
	}

	proto := 17

	var udp udphdr

	udp = udphdr{
		src: uint16(udpsrc),
		dst: uint16(udpdst),
	}

	udplen := 8 + len(dhcp)

	ip := iphdr{
		vhl:   0x45,
		tos:   0,
		id:    0x0000, // the kernel overwrites id if it is zero
		off:   0,
		ttl:   128,
		proto: uint8(proto),
	}
	copy(ip.src[:], srcIP.To4())
	copy(ip.dst[:], dstIP.To4())

	udp.ulen = uint16(udplen)
	udp.checksum(&ip, dhcp)

	totalLen := 20 + udplen

	ip.iplen = uint16(totalLen)
	ip.checksum()

	buf := bytes.NewBuffer([]byte{})
	err = binary.Write(buf, binary.BigEndian, &udp)
	if err != nil {
		log.Fatal(err)
	}

	udpHeader := buf.Bytes()
	dataWithHeader := append(udpHeader, dhcp...)

	buff := bytes.NewBuffer([]byte{})
	err = binary.Write(buff, binary.BigEndian, &ip)
	if err != nil {
		log.Fatal(err)
	}

	ipHeader := buff.Bytes()
	packet := append(ipHeader, dataWithHeader...)

	addr := syscall.SockaddrInet4{}
	copy(addr.Addr[:], dstIP.To4())
	addr.Port = int(udpdst)

	err = syscall.Sendto(s, packet, 0, &addr)
	// Send packet to target
	err = syscall.Close(s)
	if err != nil {
		log.Fatal("error closing the socket: ", err)
		os.Exit(1)
	}
	return err
}
