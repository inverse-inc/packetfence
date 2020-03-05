package main

import (
	"context"
	"fmt"
	"github.com/coreos/go-systemd/daemon"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/netflow5/processor"
	"os"
	"os/signal"
	"sync"
	"syscall"
)

func main() {
	log.SetProcessName("pfacct")

	pfacct := NewPfAcct()
	w := sync.WaitGroup{}
	rs := pfacct.radiusListen(&w)
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

	NotifySystemd("READY=1")
	defer NotifySystemd("STOPPING=1")
	processor.Start()
	w.Wait()
}

func NotifySystemd(msg string) {
	_, err := daemon.SdNotify(false, msg)
	if err != nil {
		log.LoggerWContext(context.Background(), fmt.Sprintf("Error sending systemd ready notification: %s", err.Error()))
	}
}
