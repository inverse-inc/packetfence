package sflow

import (
	"encoding/binary"
)

type CounterSamples struct {
	SequenceNumber uint32
	SourceId       uint32
	Records        []Counter
}

func (cs *CounterSamples) SampleType() uint32 {
	return CounterSamplesType
}

func (cs *CounterSamples) Parse(data []byte) {
	cs.SequenceNumber = binary.BigEndian.Uint32(data[0:4])
	cs.SourceId = binary.BigEndian.Uint32(data[4:8])
	records := binary.BigEndian.Uint32(data[8:12])
	var counter Counter
	data = data[12:]
	for i := uint32(0); i < records; i++ {
		df := DataFormat{}
		data = df.Parse(data)
		counter, data = df.ParseCounter(data)
		cs.Records = append(cs.Records, counter)
	}
}

type CountersSampleExpanded struct {
	SequenceNumber uint32
	SourceId       DataSourceExpanded
	Records        []Counter
}

func (cs *CountersSampleExpanded) SampleType() uint32 {
	return CountersSampleExpandedType
}

func (cs *CountersSampleExpanded) Parse(data []byte) {
	cs.SequenceNumber = binary.BigEndian.Uint32(data[0:4])
	cs.SourceId.Type = binary.BigEndian.Uint32(data[4:8])
	cs.SourceId.Index = binary.BigEndian.Uint32(data[8:12])
	records := binary.BigEndian.Uint32(data[12:16])
	var counter Counter
	data = data[16:]
	for i := uint32(0); i < records; i++ {
		df := DataFormat{}
		data = df.Parse(data)
		counter, data = df.ParseCounter(data)
		cs.Records = append(cs.Records, counter)
	}
}
