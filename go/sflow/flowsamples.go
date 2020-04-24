package sflow

import (
	"encoding/binary"
)

type FlowSamples struct {
	SequenceNumber uint32
	SourceId       uint32
	SamplingRate   uint32
	SamplePool     uint32
	Drops          uint32
	Input          uint32
	Output         uint32
	Records        []Flow
}

func (fs *FlowSamples) SampleType() int {
	return FlowSamplesType
}

func (fs *FlowSamples) Parse(data []byte) {
	fs.SequenceNumber = binary.BigEndian.Uint32(data[0:4])
	fs.SourceId = binary.BigEndian.Uint32(data[4:8])
	fs.SamplingRate = binary.BigEndian.Uint32(data[8:12])
	fs.SamplePool = binary.BigEndian.Uint32(data[12:16])
	fs.Drops = binary.BigEndian.Uint32(data[16:20])
	fs.Input = binary.BigEndian.Uint32(data[20:24])
	fs.Output = binary.BigEndian.Uint32(data[24:28])
	records := binary.BigEndian.Uint32(data[28:32])
	data = data[32:]
	var flow Flow
	for i := uint32(0); i < records; i++ {
		df := DataFormat{}
		data = df.Parse(data)
		flow, data = df.ParseFlow(data)
		fs.Records = append(fs.Records, flow)
	}
}
