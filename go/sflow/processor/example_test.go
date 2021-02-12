package processor_test

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
	for _, s := range samples {
		flowRecords := []sflow.Flow{}
		switch v := s.(type) {
		default:
			continue
		case *sflow.FlowSample:
			flowRecords = v.Records
		case *sflow.FlowSampleExpanded:
			flowRecords = v.Records
		}
		for i, flow := range flowRecords {
			if v, ok := flow.(*sflow.SampledIPV4); ok {
				fmt.Printf("%02d) src : %s dst :%s\n", i, net.IP(v.SrcIP[:]).String(), net.IP(v.SrcIP[:]).String())
			}
		}
	}
}

func ExampleProcessor_Start() {
	processor := processor.Processor{
		Handler: processor.SamplesHandlerFunc(HandleSamples),
	}

	processor.Start()
}

func ExampleProcessor_Start_conn() {
	conn, err := net.ListenPacket("udp", "127.0.0.2:2055")
	if err != nil {
		panic(err)
	}

	processor := processor.Processor{
		Handler: processor.SamplesHandlerFunc(HandleSamples),
		Conn:    conn,
	}

	processor.Start()
}

func ExampleProcessor_Stop() {
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
