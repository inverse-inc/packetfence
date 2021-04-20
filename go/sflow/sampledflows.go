package sflow

import (
	"encoding/binary"
	"github.com/inverse-inc/go-utils/mac"
)

type SampledEthernet struct {
	Length uint32
	SrcMac mac.Mac
	DstMac mac.Mac
	Type   uint32
}

func (se *SampledEthernet) Parse(data []byte) {
	se.Length = binary.BigEndian.Uint32(data[0:4])
	copy(se.SrcMac[:], data[4:10])
	copy(se.DstMac[:], data[10:16])
	se.Type = binary.BigEndian.Uint32(data[16:20])
}

func (se *SampledEthernet) FlowType() uint32 {
	return SampledEthernetType
}

type SampledUnknown struct {
	Type uint32
	Data []byte
}

func (u *SampledUnknown) Parse(data []byte) {
	u.Data = make([]byte, len(data))
	copy(u.Data, data)
}

func (u *SampledUnknown) FlowType() uint32 {
	return u.Type
}

type SampledIPV4 struct {
	Length   uint32
	Protocol uint32
	SrcIP    [4]byte
	DstIP    [4]byte
	SrcPort  uint32
	DstPort  uint32
	TCPFlags uint32
	ToS      uint32
}

func (si *SampledIPV4) Parse(data []byte) {
	si.Length = binary.BigEndian.Uint32(data[0:4])
	si.Protocol = binary.BigEndian.Uint32(data[4:8])
	copy(si.SrcIP[:], data[8:12])
	copy(si.DstIP[:], data[12:16])
	si.SrcPort = binary.BigEndian.Uint32(data[16:20])
	si.DstPort = binary.BigEndian.Uint32(data[20:24])
	si.TCPFlags = binary.BigEndian.Uint32(data[24:28])
	si.ToS = binary.BigEndian.Uint32(data[28:32])
}

func (u *SampledIPV4) FlowType() uint32 {
	return SampledIPV4Type
}

func (si *SampledIPV4) ParseFromIPHeader(data []byte) {
	copy(si.SrcIP[:], data[12:16])
	copy(si.DstIP[:], data[16:20])
	si.Protocol = uint32(data[9])
	if si.Protocol == 6 || si.Protocol == 17 {
		length := int((data[0] & 0xF) * 4)
		si.SrcPort = uint32(binary.BigEndian.Uint16(data[length : length+2]))
		si.DstPort = uint32(binary.BigEndian.Uint16(data[length+2 : length+4]))
	}
}

type SampledIPV6 struct {
	Length   uint32
	Protocol uint32
	SrcIP    [16]byte
	DstIP    [16]byte
	SrcPort  uint32
	DstPort  uint32
	TCPFlags uint32
	ToS      uint32
}

func (si *SampledIPV6) Parse(data []byte) {
	si.Length = binary.BigEndian.Uint32(data[0:4])
	si.Protocol = binary.BigEndian.Uint32(data[4:8])
	copy(si.SrcIP[:], data[8:24])
	copy(si.DstIP[:], data[12:40])
	si.SrcPort = binary.BigEndian.Uint32(data[40:44])
	si.DstPort = binary.BigEndian.Uint32(data[44:48])
	si.TCPFlags = binary.BigEndian.Uint32(data[48:52])
	si.ToS = binary.BigEndian.Uint32(data[52:56])
}

func (u *SampledIPV6) FlowType() uint32 {
	return SampledIPV4Type
}
