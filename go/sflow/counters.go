package sflow

import (
	"encoding/binary"
)

type TokenringCounters struct {
	StatsLineErrors         uint32
	StatsBurstErrors        uint32
	StatsACErrors           uint32
	StatsAbortTransErrors   uint32
	StatsInternalErrors     uint32
	StatsLostFrameErrors    uint32
	StatsReceiveCongestions uint32
	StatsFrameCopiedErrors  uint32
	StatsTokenErrors        uint32
	StatsSoftErrors         uint32
	StatsHardErrors         uint32
	StatsSignalLoss         uint32
	StatsTransmitBeacons    uint32
	StatsRecoverys          uint32
	StatsLobeWires          uint32
	StatsRemoves            uint32
	StatsSingles            uint32
	StatsFreqErrors         uint32
}

func (tc *TokenringCounters) Parse(data []byte) {
	tc.StatsLineErrors = binary.BigEndian.Uint32(data[0:4])
	tc.StatsBurstErrors = binary.BigEndian.Uint32(data[4:8])
	tc.StatsACErrors = binary.BigEndian.Uint32(data[8:12])
	tc.StatsAbortTransErrors = binary.BigEndian.Uint32(data[12:16])
	tc.StatsInternalErrors = binary.BigEndian.Uint32(data[16:20])
	tc.StatsLostFrameErrors = binary.BigEndian.Uint32(data[20:24])
	tc.StatsReceiveCongestions = binary.BigEndian.Uint32(data[24:28])
	tc.StatsFrameCopiedErrors = binary.BigEndian.Uint32(data[28:32])
	tc.StatsTokenErrors = binary.BigEndian.Uint32(data[32:36])
	tc.StatsSoftErrors = binary.BigEndian.Uint32(data[36:40])
	tc.StatsHardErrors = binary.BigEndian.Uint32(data[40:44])
	tc.StatsSignalLoss = binary.BigEndian.Uint32(data[44:48])
	tc.StatsTransmitBeacons = binary.BigEndian.Uint32(data[48:52])
	tc.StatsRecoverys = binary.BigEndian.Uint32(data[52:56])
	tc.StatsLobeWires = binary.BigEndian.Uint32(data[56:60])
	tc.StatsRemoves = binary.BigEndian.Uint32(data[60:64])
	tc.StatsSingles = binary.BigEndian.Uint32(data[64:68])
	tc.StatsFreqErrors = binary.BigEndian.Uint32(data[68:72])
}

func (tc *TokenringCounters) CounterType() uint32 {
	return 3
}

type VGCounters struct {
	InHighPriorityFrames    uint32
	InNormPriorityFrames    uint32
	InHighPriorityOctets    uint64
	InNormPriorityOctets    uint64
	InIPMErrors             uint32
	InOversizeFrameErrors   uint32
	InDataErrors            uint32
	InNullAddressedFrames   uint32
	OutHighPriorityFrames   uint32
	TransitionIntoTrainings uint32
	OutHighPriorityOctets   uint64
	HCInHighPriorityOctets  uint64
	HCInNormPriorityOctets  uint64
	HCOutHighPriorityOctets uint64
}

func (*VGCounters) CounterType() uint32 {
	return 4
}

func (vc *VGCounters) Parse(data []byte) {
	vc.InHighPriorityFrames = binary.BigEndian.Uint32(data[0:4])
	vc.InHighPriorityOctets = binary.BigEndian.Uint64(data[4:12])
	vc.InNormPriorityFrames = binary.BigEndian.Uint32(data[12:16])
	vc.InNormPriorityOctets = binary.BigEndian.Uint64(data[16:24])
	vc.InIPMErrors = binary.BigEndian.Uint32(data[24:28])
	vc.InOversizeFrameErrors = binary.BigEndian.Uint32(data[28:32])
	vc.InDataErrors = binary.BigEndian.Uint32(data[32:36])
	vc.InNullAddressedFrames = binary.BigEndian.Uint32(data[36:40])
	vc.OutHighPriorityFrames = binary.BigEndian.Uint32(data[40:44])
	vc.OutHighPriorityOctets = binary.BigEndian.Uint64(data[44:52])
	vc.TransitionIntoTrainings = binary.BigEndian.Uint32(data[52:56])
	vc.HCInHighPriorityOctets = binary.BigEndian.Uint64(data[56:64])
	vc.HCInNormPriorityOctets = binary.BigEndian.Uint64(data[64:72])
	vc.HCOutHighPriorityOctets = binary.BigEndian.Uint64(data[72:80])
}

type CounterUnknown struct {
	Type uint32
	Data []byte
}

func (u *CounterUnknown) Parse(data []byte) {
	u.Data = make([]byte, len(data))
	copy(u.Data, data)
}

func (u *CounterUnknown) CounterType() uint32 {
	return u.Type
}

type VlanCounters struct {
	VLANID        uint32
	Octets        uint64
	UcastPkts     uint32
	MulticastPkts uint32
	BroadcastPkts uint32
	Discards      uint32
}

func (*VlanCounters) CounterType() uint32 {
	return VlanCountersType
}

func (vc *VlanCounters) Parse(data []byte) {
	vc.VLANID = binary.BigEndian.Uint32(data[0:4])
	vc.Octets = binary.BigEndian.Uint64(data[4:12])
	vc.UcastPkts = binary.BigEndian.Uint32(data[12:16])
	vc.MulticastPkts = binary.BigEndian.Uint32(data[16:20])
	vc.BroadcastPkts = binary.BigEndian.Uint32(data[20:24])
	vc.Discards = binary.BigEndian.Uint32(data[24:28])
}

type Processor struct {
	CPU_5s      uint32
	CPU_1m      uint32
	CPU_5m      uint32
	TotalMemory uint64
	FreeMemory  uint64
}

func (*Processor) CounterType() uint32 {
	return ProcessorType
}

func (p *Processor) Parse(data []byte) {
	p.CPU_5s = binary.BigEndian.Uint32(data[0:4])
	p.CPU_1m = binary.BigEndian.Uint32(data[4:8])
	p.CPU_5m = binary.BigEndian.Uint32(data[8:12])
	p.TotalMemory = binary.BigEndian.Uint64(data[12:20])
	p.FreeMemory = binary.BigEndian.Uint64(data[20:28])
}
