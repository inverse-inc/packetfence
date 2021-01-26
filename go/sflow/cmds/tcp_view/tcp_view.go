package main

import (
	"fmt"
	"github.com/inverse-inc/packetfence/go/sflow"
	"github.com/inverse-inc/packetfence/go/sflow/processor"
	"net"
	"os"
	"os/signal"
)

func HandleSamples(header *sflow.Header, samples []sflow.Sample) {
	fmt.Printf("Got some\n")
	fmt.Printf("Got %d samples\n", len(samples))
	for _, s := range samples {
		flowRecords := []sflow.Flow{}
		counterRecords := []sflow.Counter{}
		switch v := s.(type) {
		default:
			continue
		case *sflow.FlowSample:
			flowRecords = v.Records
		case *sflow.FlowSampleExpanded:
			flowRecords = v.Records
		case *sflow.CounterSamples:
			counterRecords = v.Records
		}

		if flowRecords != nil {
			for i, flow := range flowRecords {
				var ip4 *sflow.SampledIPV4
				switch v := flow.(type) {
				case *sflow.SampledIPV4:
					ip4 = v
				case *sflow.SampledHeader:
					ip4 = v.SampledIPv4()
					if ip4 != nil && (ip4.Protocol != 6 && ip4.Protocol != 17) {
						ip4 = nil
					}
				}
				if ip4 != nil {
					fmt.Printf("%02d) src : %s dst : %s, (%d, %d)\n", i, net.IP(ip4.SrcIP[:]).String(), net.IP(ip4.SrcIP[:]).String(), ip4.SrcPort, ip4.DstPort)
				}
			}
		}
		if counterRecords != nil {
			for i, counter := range counterRecords {
				fmt.Printf("%d) %d\n", i, counter.CounterType())
			}
		}
	}
}

func main() {
	processor := processor.Processor{
		Handler: processor.SamplesHandlerFunc(HandleSamples),
	}
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		<-c
		processor.Stop()
	}()

	processor.Start()
}
