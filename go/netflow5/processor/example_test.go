package processor_test

import (
	"fmt"
	"github.com/inverse-inc/packetfence/go/netflow5"
	"github.com/inverse-inc/packetfence/go/netflow5/processor"
	"net"
	"os"
	"os/signal"
)

func HandleNetFlowV5(header *netflow5.Header, i int, flow *netflow5.Flow) {
	fmt.Printf("%02d) src : %s dst :%s, next : %s \n", i, flow.SrcIP().String(), flow.DstIP().String(), flow.NextIP().String())
}

func ExampleProcessor_Start() {
	processor := processor.Processor{
		Handler: HandleNetFlowV5,
	}

	processor.Start()
}

func ExampleProcessor_Start_conn() {
	conn, err := net.ListenPacket("udp", "127.0.0.2:2055")
	if err != nil {
		panic(err)
	}

	processor := processor.Processor{
		Handler: HandleNetFlowV5,
		Conn:    conn,
	}

	processor.Start()
}

func ExampleProcessor_Stop() {
	processor := processor.Processor{
		Handler: HandleNetFlowV5,
	}
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		<-c
		processor.Stop()
	}()

	processor.Start()
}
