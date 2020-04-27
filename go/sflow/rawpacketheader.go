package sflow

import (
	"encoding/binary"
)

type RawPacketHeader struct {
	Protocol             uint32
	FrameLength          uint32
	PayloadRemoved       uint32
	OriginalPacketLength uint32

}

func (rp *RawPacketHeader) Parse(data []byte) {
	rp.Protocol = binary.BigEndian.Uint32(data[0:4])
	rp.FrameLength = binary.BigEndian.Uint32(data[4:8])
	rp.PayloadRemoved = binary.BigEndian.Uint32(data[8:12])
	rp.OriginalPacketLength = binary.BigEndian.Uint32(data[12:16])
}

func (rp *RawPacketHeader) FlowType() int {
	return 1
}
