package main

import (
	_ "fmt"
	"github.com/inverse-inc/packetfence/go/netflow5/processor"
    "sync"
	"os"
    "context"
    "syscall"
	"os/signal"
)

func main() {
    w := sync.WaitGroup{}
    rs := radiusListen(&w)
	processor := processor.Processor{
		Handler: NewBandwidthAccountingNetFlow(),
	}
    w.Add(1)
	c := make(chan os.Signal, 1)
	signal.Notify(c, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-c
        rs.Shutdown(context.Background())
		processor.Stop()
        w.Done()
	}()

	processor.Start()
    w.Wait()
}
