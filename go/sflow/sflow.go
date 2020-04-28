package sflow

import (
	"encoding/binary"
)

const (
	FlowSampleType uint32 = iota + 1
	CounterSamplesType
	FlowSampleExpandedType
	CountersSampleExpandedType
)

const (
	SampledUnknownType uint32 = iota
	SampledHeaderType
	SampledEthernetType
	SampledIPV4Type
	SampledIPV6Type
)

const (
	ExtendedSwitchType uint32 = iota + 1001
	ExtendedRouterType
	ExtendedGatewayType
	ExtendedUserType
	ExtendedURLType
	ExtendedMPLSType
	ExtendedNATType
	ExtendedMPLSTunnelType
	ExtendedMPLSVCType
	ExtendedMPLSFTNType
	ExtendedMPLSLDPFECType
	ExtendedVLANTunnelType
)

const (
	IfCountersType uint32 = iota + 1
	EthernetCountersType
	TokenringCountersType
	VGCountersType
	VlanCountersType
)

const (
	ProcessorType = 1001
)

type Sample interface {
	SampleType() uint32
	Parse([]byte)
}

type Counter interface {
	CounterType() uint32
	Parse([]byte)
}

type Flow interface {
	FlowType() uint32
	Parse([]byte)
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

func (df *DataFormat) ParseFlow(data []byte) (Flow, []byte) {
	var flow Flow
	switch df.Format {
	default:
		flow = &SampledUnknown{Type: df.Format}
	case SampledHeaderType:
		flow = &SampledHeader{}
	case SampledIPV4Type:
		flow = &SampledIPV4{}
	case SampledIPV6Type:
		flow = &SampledIPV6{}
	}

	if flow != nil {
		flow.Parse(data)
	}

	return flow, data[df.Length:]
}

func (h *Header) ParseSamples(data []byte) ([]Sample, error) {
	dfs := []DataFormat{}
	samples := []Sample{}
	var sample Sample
	for i := uint32(0); i < h.NumSamples; i++ {
		df := DataFormat{}
		data = df.Parse(data)
		dfs = append(dfs, df)
		sample, data = df.ParseSample(data)
		samples = append(samples, sample)
	}

	return samples, nil
}

func (df *DataFormat) ParseSample(data []byte) (Sample, []byte) {
	var sample Sample
	switch df.Format {
	case CounterSamplesType:
		sample = &CounterSamples{}
	case FlowSampleType:
		sample = &FlowSample{}
	case FlowSampleExpandedType:
		sample = &FlowSampleExpanded{}
	}

	if sample != nil {
		sample.Parse(data)
	}

	return sample, data[df.Length:]
}

func (df *DataFormat) ParseCounter(data []byte) (Counter, []byte) {
	var counter Counter
	switch df.Format {
	default:
		counter = &CounterUnknown{Type: df.Format}
	case IfCountersType:
		counter = &IfCounter{}
	case EthernetCountersType:
		counter = &EthernetCounter{}
	case TokenringCountersType:
		counter = &TokenringCounters{}
	case VGCountersType:
		counter = &VGCounters{}
	case VlanCountersType:
		counter = &VlanCounters{}
	case ProcessorType:
		counter = &Processor{}
	}

	if counter != nil {
		counter.Parse(data)
	}

	return counter, data[df.Length:]
}
