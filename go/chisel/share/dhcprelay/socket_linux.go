package dhcprelay

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"net"
	"os"
	"syscall"

	"github.com/mdlayher/ethernet"
	"github.com/mdlayher/raw"
)

// openBroadcastConn opens the UDP/67 socket of one interface. Bound to
// INADDR_ANY with SO_BINDTODEVICE it receives both the broadcasts of clients
// without an address and the unicasts renewing clients send to our address,
// and only those arriving on that interface. SO_REUSEADDR lets one such
// socket exist per VLAN interface.
func openBroadcastConn(iface Interface) (net.PacketConn, error) {
	s, err := syscall.Socket(syscall.AF_INET, syscall.SOCK_DGRAM, syscall.IPPROTO_UDP)
	if err != nil {
		return nil, fmt.Errorf("socket: %w", err)
	}
	closeOnErr := func(err error) (net.PacketConn, error) {
		syscall.Close(s)
		return nil, err
	}
	if err := syscall.SetsockoptInt(s, syscall.SOL_SOCKET, syscall.SO_REUSEADDR, 1); err != nil {
		return closeOnErr(fmt.Errorf("SO_REUSEADDR: %w", err))
	}
	if err := syscall.SetsockoptInt(s, syscall.SOL_SOCKET, syscall.SO_BROADCAST, 1); err != nil {
		return closeOnErr(fmt.Errorf("SO_BROADCAST: %w", err))
	}
	if err := syscall.SetsockoptString(s, syscall.SOL_SOCKET, syscall.SO_BINDTODEVICE, iface.Name); err != nil {
		return closeOnErr(fmt.Errorf("SO_BINDTODEVICE %s: %w", iface.Name, err))
	}
	lsa := syscall.SockaddrInet4{Port: bootpServerPort}
	if err := syscall.Bind(s, &lsa); err != nil {
		return closeOnErr(fmt.Errorf("bind :%d on %s: %w", bootpServerPort, iface.Name, err))
	}
	f := os.NewFile(uintptr(s), "dhcp-relay-"+iface.Name)
	conn, err := net.FilePacketConn(f)
	f.Close() // FilePacketConn dup'ed the descriptor
	if err != nil {
		return nil, fmt.Errorf("FilePacketConn: %w", err)
	}
	return conn, nil
}

// sendLayer2 writes one UDP 67->68 datagram to dstMAC/dstIP as a hand-built
// Ethernet/IPv4/UDP frame on iface. Needed because the client does not own
// dstIP yet (OFFER/ACK to a fresh lease) so the kernel could not ARP it.
// Same construction as pfdhcp's rawClient.
func sendLayer2(iface Interface, dstMAC net.HardwareAddr, dstIP net.IP, payload []byte) error {
	ifi, err := net.InterfaceByName(iface.Name)
	if err != nil {
		return err
	}
	// The ethertype only filters what we *receive*; we never read from it.
	p, err := raw.ListenPacket(ifi, 0x0806, &raw.Config{})
	if err != nil {
		return fmt.Errorf("raw socket on %s: %w", iface.Name, err)
	}
	defer p.Close()

	udpLen := 8 + len(payload)
	ipLen := 20 + udpLen
	ip := ipv4Header{
		vhl:   0x45,
		id:    0,
		ttl:   64,
		proto: syscall.IPPROTO_UDP,
		iplen: uint16(ipLen),
	}
	copy(ip.src[:], iface.IP.To4())
	copy(ip.dst[:], dstIP.To4())
	ip.csum = checksum(ip.bytes())

	udp := udpHeader{src: bootpServerPort, dst: bootpClientPort, ulen: uint16(udpLen)}
	udp.csum = udpChecksum(&ip, udp, payload)

	frame := &ethernet.Frame{
		Destination: dstMAC,
		Source:      ifi.HardwareAddr,
		EtherType:   ethernet.EtherTypeIPv4,
		Payload:     append(append(ip.bytes(), udp.bytes()...), payload...),
	}
	fb, err := frame.MarshalBinary()
	if err != nil {
		return err
	}
	_, err = p.WriteTo(fb, &raw.Addr{HardwareAddr: dstMAC})
	return err
}

type ipv4Header struct {
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

func (h *ipv4Header) bytes() []byte {
	b := &bytes.Buffer{}
	binary.Write(b, binary.BigEndian, h)
	return b.Bytes()
}

type udpHeader struct {
	src  uint16
	dst  uint16
	ulen uint16
	csum uint16
}

func (h udpHeader) bytes() []byte {
	b := &bytes.Buffer{}
	binary.Write(b, binary.BigEndian, h)
	return b.Bytes()
}

// udpChecksum over the IPv4 pseudo header, the UDP header and the payload.
func udpChecksum(ip *ipv4Header, udp udpHeader, payload []byte) uint16 {
	pseudo := &bytes.Buffer{}
	pseudo.Write(ip.src[:])
	pseudo.Write(ip.dst[:])
	pseudo.WriteByte(0)
	pseudo.WriteByte(ip.proto)
	binary.Write(pseudo, binary.BigEndian, udp.ulen)
	udp.csum = 0
	data := append(append(pseudo.Bytes(), udp.bytes()...), payload...)
	if len(data)%2 == 1 {
		data = append(data, 0)
	}
	return checksum(data)
}

// checksum is the ones' complement sum used by IPv4 and UDP.
func checksum(buf []byte) uint16 {
	var sum uint32
	for i := 0; i+1 < len(buf); i += 2 {
		sum += uint32(buf[i])<<8 | uint32(buf[i+1])
	}
	if len(buf)%2 == 1 {
		sum += uint32(buf[len(buf)-1]) << 8
	}
	for sum > 0xffff {
		sum = (sum >> 16) + (sum & 0xffff)
	}
	return ^uint16(sum)
}
