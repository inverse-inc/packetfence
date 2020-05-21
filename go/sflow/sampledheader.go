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

func (sh *SampledHeader) Parse(data []byte) {
	sh.Protocol = binary.BigEndian.Uint32(data[0:4])
	sh.FrameLength = binary.BigEndian.Uint32(data[4:8])
	sh.PayloadRemoved = binary.BigEndian.Uint32(data[8:12])
	headerlength := binary.BigEndian.Uint32(data[12:16])
	sh.Header = make([]byte, headerlength)
	copy(sh.Header, data[16:16+headerlength])
}

func (*SampledHeader) FlowType() uint32 {
	return SampledHeaderType
}

func (sh *SampledHeader) SampledIPv4() *SampledIPV4 {
	var sampleIPv4 *SampledIPV4
	switch sh.Protocol {
	case 1:
		ethernetHeaderSize := 14
		header := sh.Header
		switch binary.BigEndian.Uint16(header[12:14]) {
		case 0x8100:
			ethernetHeaderSize += 4
		case 0x88a8:
			ethernetHeaderSize += 8
		}
		sampleIPv4 = &SampledIPV4{}
		sampleIPv4.ParseFromIPHeader(header[ethernetHeaderSize:])
	case 11:
		sampleIPv4 = &SampledIPV4{}
		sampleIPv4.ParseFromIPHeader(sh.Header)
	}

	return sampleIPv4
}
