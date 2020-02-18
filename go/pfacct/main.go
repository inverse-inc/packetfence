package main

import (
	"context"
	_ "fmt"
	"github.com/inverse-inc/packetfence/go/netflow5/processor"
	"os"
	"os/signal"
	"sync"
	"syscall"
)

func main() {
	pfacct := NewPfAcct()
	w := sync.WaitGroup{}
	pfRadius := NewPfRadius()
	rs := pfRadius.radiusListen(&w)
	processor := processor.Processor{
		Handler: pfacct,
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
