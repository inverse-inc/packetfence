package sflow

import (
	"encoding/binary"
)

type SampledHeader struct {
	Protocol       uint32
	FrameLength    uint32
	PayloadRemoved uint32
	Header         []byte
}

func (rp *SampledHeader) Parse(data []byte) {
	rp.Protocol = binary.BigEndian.Uint32(data[0:4])
	rp.FrameLength = binary.BigEndian.Uint32(data[4:8])
	rp.PayloadRemoved = binary.BigEndian.Uint32(data[8:12])
	headerlength := binary.BigEndian.Uint32(data[12:16])
	rp.Header = make([]byte, headerlength)
	copy(rp.Header, data[16:16+headerlength])
}

func (rp *SampledHeader) FlowType() uint32 {
	return SampledHeaderType
}
