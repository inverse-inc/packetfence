package sflow

import (
	"encoding/binary"
)

type EthernetCounter struct {
	AlignmentErrors           uint32
	FCSErrors                 uint32
	SingleCollisionFrames     uint32
	MultipleCollisionFrames   uint32
	SQETestErrors             uint32
	DeferredTransmissions     uint32
	LateCollisions            uint32
	ExcessiveCollisions       uint32
	InternalMacTransmitErrors uint32
	CarrierSenseErrors        uint32
	FrameTooLongs             uint32
	InternalMacReceiveErrors  uint32
	SymbolErrors              uint32
}

func (eic *EthernetCounter) CounterType() uint32 {
	return EthernetCountersType
}

func (eic *EthernetCounter) Parse(data []byte) {
	eic.AlignmentErrors = binary.BigEndian.Uint32(data[0:4])
	eic.FCSErrors = binary.BigEndian.Uint32(data[4:8])
	eic.SingleCollisionFrames = binary.BigEndian.Uint32(data[8:12])
	eic.MultipleCollisionFrames = binary.BigEndian.Uint32(data[12:16])
	eic.SQETestErrors = binary.BigEndian.Uint32(data[16:20])
	eic.DeferredTransmissions = binary.BigEndian.Uint32(data[20:24])
	eic.LateCollisions = binary.BigEndian.Uint32(data[24:28])
	eic.ExcessiveCollisions = binary.BigEndian.Uint32(data[28:32])
	eic.InternalMacTransmitErrors = binary.BigEndian.Uint32(data[32:36])
	eic.CarrierSenseErrors = binary.BigEndian.Uint32(data[36:40])
	eic.FrameTooLongs = binary.BigEndian.Uint32(data[40:44])
	eic.InternalMacReceiveErrors = binary.BigEndian.Uint32(data[44:48])
	eic.SymbolErrors = binary.BigEndian.Uint32(data[48:52])
}
