package sflow

import (
    "encoding/binary"
)

type CounterSamples struct {
	SequenceNumber uint32
	SourceId       uint32
	Records        []Counter
}

func (cs *CounterSamples) SampleType() int {
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
