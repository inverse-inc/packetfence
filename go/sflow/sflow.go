package sflow

import (
	"encoding/binary"
)

type Sample interface {
	SampleType() int
	Parse([]byte)
}

type Counter interface {
	Parse([]byte)
	CounterType() int
}

type Flow interface {
	Parse([]byte)
	FlowType() int
}

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

func (h *CountersSample) Parse(data []byte) []byte {
	h.SequenceNumber = binary.BigEndian.Uint32(data[0:4])
	h.SourceId = binary.BigEndian.Uint32(data[4:8])
	h.NumSamples = binary.BigEndian.Uint32(data[8:12])
	return data[12:]
}
