package netflow5

import "net"

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
	TcpFlags byte    // 38
	Proto    byte    // 39
	Tos      byte    // 40
	nSrcAs   uint16  // 42
	nDstAs   uint16  // 44
	SrcMask  uint8   // 45
	DstMask  uint8   // 46
	pad2     [2]byte // 48
}

func (flow *Flow) SrcIP() net.IP { return net.IP(flow.SrcAddr[:]) }
func (flow *Flow) DstIP() net.IP { return net.IP(flow.DstAddr[:]) }
func (flow *Flow) NextIP() net.IP { return net.IP(flow.NextAddr[:]) }
func (flow *Flow) DPkts() uint32   { return Ntoh32(flow.nDPkts) }
func (flow *Flow) DOctets() uint32 { return Ntoh32(flow.nDOctets) }
func (flow *Flow) First() uint32   { return Ntoh32(flow.nFirst) }
func (flow *Flow) Last() uint32    { return Ntoh32(flow.nLast) }
func (flow *Flow) SrcPort() uint16 { return Ntoh16(flow.nSrcPort) }
func (flow *Flow) DstPort() uint16 { return Ntoh16(flow.nDstPort) }
func (flow *Flow) SrcAs() uint16   { return Ntoh16(flow.nSrcAs) }
func (flow *Flow) DstAs() uint16   { return Ntoh16(flow.nDstAs) }
func (flow *Flow) Input() uint16   { return Ntoh16(flow.nInput) }
func (flow *Flow) Output() uint16  { return Ntoh16(flow.nOutput) }
