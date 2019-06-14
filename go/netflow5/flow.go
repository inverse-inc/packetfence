package netflow5

import "net"

// Flow in memory layout of a netflow5 flow
type Flow struct {
	SrcAddr  [4]byte // 4
	DstAddr  [4]byte // 8
	NextAddr [4]byte // 12
	nInput   uint16  // 14
	nOutput  uint16  // 16
	nDPkts   uint32  // 20
	nDOctets uint32  // 24
	nFirst   uint32  // 28
	nLast    uint32  // 32
	nSrcPort uint16  // 34
	nDstPort uint16  // 36
	pad1     byte    // 37
	// TCPFlags cumulative OR of TCP flags.
	TCPFlags byte // 38
	// Proto IP protocol type (for example, TCP = 6; UDP = 17)
	Proto byte // 39
	// Tos IP type of service (ToS)
	Tos    byte   // 40
	nSrcAs uint16 // 42
	nDstAs uint16 // 44
	// SrcMask Source address prefix mask bits
	SrcMask uint8 // 45
	// DstMask Destination address prefix mask bits
	DstMask uint8   // 46
	pad2    [2]byte // 48
}

// SrcIP returns the source IP address of the flow.
func (flow *Flow) SrcIP() net.IP { return net.IP(flow.SrcAddr[:]) }

// DstIP returns the destination IP address of the flow.
func (flow *Flow) DstIP() net.IP { return net.IP(flow.DstAddr[:]) }

// NextIP returns the next IP address of the flow.
func (flow *Flow) NextIP() net.IP { return net.IP(flow.NextAddr[:]) }

// DPkts returns number of packets in the flow.
func (flow *Flow) DPkts() uint32 { return ntoh32(flow.nDPkts) }

// DOctets returns total number of Layer 3 bytes in the packets of the flow.
func (flow *Flow) DOctets() uint32 { return ntoh32(flow.nDOctets) }

// First returns system uptime at start of flow.
func (flow *Flow) First() uint32 { return ntoh32(flow.nFirst) }

// Last returns system uptime at the time the last packet of the flow was received.
func (flow *Flow) Last() uint32 { return ntoh32(flow.nLast) }

// SrcPort returns TCP/UDP source port number or equivalent.
func (flow *Flow) SrcPort() uint16 { return ntoh16(flow.nSrcPort) }

// DstPort TCP/UDP destination port number or equivalent.
func (flow *Flow) DstPort() uint16 { return ntoh16(flow.nDstPort) }

// SrcAs returns Autonomous system number of the source, either origin or peer.
func (flow *Flow) SrcAs() uint16 { return ntoh16(flow.nSrcAs) }

// DstAs returns Autonomous system number of the destination, either origin or peer
func (flow *Flow) DstAs() uint16 { return ntoh16(flow.nDstAs) }

// Input returns SNMP index of input interface
func (flow *Flow) Input() uint16 { return ntoh16(flow.nInput) }

// Output returns SNMP index of output interface
func (flow *Flow) Output() uint16 { return ntoh16(flow.nOutput) }
