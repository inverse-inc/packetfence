package sflow

import (
	"encoding/binary"
)

type FlowSample struct {
	SequenceNumber uint32
	SourceId       uint32
	SamplingRate   uint32
	SamplePool     uint32
	Drops          uint32
	Input          uint32
	Output         uint32
	Records        []Flow
}

func (fs *FlowSample) SampleType() uint32 {
	return FlowSampleType
}

func (fs *FlowSample) Parse(data []byte) {
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

type DataSourceExpanded struct {
	Type  uint32
	Index uint32
}

type InterfaceExpanded struct {
	Format uint32
	Value  uint32
}

/* Format of a single expanded flow sample */
/* opaque = sample_data; enterprise = 0; format = 3 */

type FlowSampleExpanded struct {
	SequenceNumber uint32
	SourceId       DataSourceExpanded
	SamplingRate   uint32
	SamplePool     uint32
	Drops          uint32
	Input          InterfaceExpanded
	Output         InterfaceExpanded
	Records        []Flow
}

func (fs *FlowSampleExpanded) SampleType() uint32 {
	return FlowSampleExpandedType
}

func (fs *FlowSampleExpanded) Parse(data []byte) {
	fs.SequenceNumber = binary.BigEndian.Uint32(data[0:4])
	fs.SourceId.Type = binary.BigEndian.Uint32(data[4:8])
	fs.SourceId.Index = binary.BigEndian.Uint32(data[8:12])
	fs.SamplingRate = binary.BigEndian.Uint32(data[12:16])
	fs.SamplePool = binary.BigEndian.Uint32(data[16:20])
	fs.Drops = binary.BigEndian.Uint32(data[20:24])
	fs.Input.Format = binary.BigEndian.Uint32(data[24:28])
	fs.Input.Value = binary.BigEndian.Uint32(data[28:32])
	fs.Output.Format = binary.BigEndian.Uint32(data[32:36])
	fs.Output.Value = binary.BigEndian.Uint32(data[36:40])
	records := binary.BigEndian.Uint32(data[40:44])
	data = data[44:]
	var flow Flow
	for i := uint32(0); i < records; i++ {
		df := DataFormat{}
		data = df.Parse(data)
		flow, data = df.ParseFlow(data)
		fs.Records = append(fs.Records, flow)
	}
}
