package sflow

import (
	"encoding/binary"
)

type Header struct {
	Version        uint32
	AddressType    uint32
	AgentAddress   [4]byte
	SubAgentID     uint32
	SequenceNumber uint32
	SysUptime      uint32
	NumSamples     uint32
}

func (h *Header) Parse(data []byte) []byte {
	h.Version = binary.BigEndian.Uint32(data[0:4])
	h.AddressType = binary.BigEndian.Uint32(data[4:8])
	copy(h.AgentAddress[:], data[4:12])
	h.SubAgentID = binary.BigEndian.Uint32(data[12:16])
	h.SequenceNumber = binary.BigEndian.Uint32(data[16:20])
	h.SysUptime = binary.BigEndian.Uint32(data[20:24])
	h.NumSamples = binary.BigEndian.Uint32(data[24:28])
	return data[28:]
}

type DataFormat struct {
	Format uint32
	Length uint32
}

func (h *DataFormat) Parse(data []byte) []byte {
	h.Format = binary.BigEndian.Uint32(data[0:4])
	h.Length = binary.BigEndian.Uint32(data[4:8])
	return data[8:]
}

type CountersSample struct {
	SequenceNumber uint32
	SourceId       uint32
	NumSamples     uint32
}

type IfCounter struct {
	Index     uint32
	Type      uint32
	Speed     uint64
	Direction uint32 /* derived from MAU MIB (RFC 2668)
	   0 = unkown, 1=full-duplex, 2=half-duplex,
	   3 = in, 4=out */
	Status uint32 /* bit field with the following bits assigned
	   bit 0 = ifAdminStatus (0 = down, 1 = up)
	   bit 1 = ifOperStatus (0 = down, 1 = up) */
	InOctets         uint64
	InUcastPkts      uint32
	InMulticastPkts  uint32
	InBroadcastPkts  uint32
	InDiscards       uint32
	InErrors         uint32
	InUnknownProtos  uint32
	OutOctets        uint64
	OutUcastPkts     uint32
	OutMulticastPkts uint32
	OutBroadcastPkts uint32
	OutDiscards      uint32
	OutErrors        uint32
	PromiscuousMode  uint32
}

func (ic *IfCounter) Parse(data []byte) []byte {
	ic.Index = binary.BigEndian.Uint32(data[0:4])
	ic.Type = binary.BigEndian.Uint32(data[4:8])
	ic.Speed = binary.BigEndian.Uint64(data[8:16])
	ic.Direction = binary.BigEndian.Uint32(data[16:20])
	ic.Status = binary.BigEndian.Uint32(data[20:24])
	ic.InOctets = binary.BigEndian.Uint64(data[24:32])
	ic.InUcastPkts = binary.BigEndian.Uint32(data[32:36])
	ic.InMulticastPkts = binary.BigEndian.Uint32(data[36:40])
	ic.InBroadcastPkts = binary.BigEndian.Uint32(data[40:44])
	ic.InDiscards = binary.BigEndian.Uint32(data[44:48])
	ic.InErrors = binary.BigEndian.Uint32(data[48:52])
	ic.InUnknownProtos = binary.BigEndian.Uint32(data[52:56])
	ic.OutOctets = binary.BigEndian.Uint64(data[56:64])
	ic.OutUcastPkts = binary.BigEndian.Uint32(data[64:68])
	ic.OutMulticastPkts = binary.BigEndian.Uint32(data[68:72])
	ic.OutBroadcastPkts = binary.BigEndian.Uint32(data[72:76])
	ic.OutDiscards = binary.BigEndian.Uint32(data[76:80])
	ic.OutErrors = binary.BigEndian.Uint32(data[80:84])
	ic.PromiscuousMode = binary.BigEndian.Uint32(data[84:88])
	return data[88:]
}

func (h *CountersSample) Parse(data []byte) []byte {
	h.SequenceNumber = binary.BigEndian.Uint32(data[0:4])
	h.SourceId = binary.BigEndian.Uint32(data[4:8])
	h.NumSamples = binary.BigEndian.Uint32(data[8:12])
	return data[12:]
}
