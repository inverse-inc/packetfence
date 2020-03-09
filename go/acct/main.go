package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/coreos/go-systemd/daemon"
	"github.com/inverse-inc/packetfence/go/log"
)

func main() {
	log.SetProcessName("pfacct")

	pfacct := NewPfAcct()
	w := sync.WaitGroup{}
	rs := pfacct.radiusListen(&w)
	processor, _ := pfacct.netflowProcessor()
	w.Add(1)
	c := make(chan os.Signal, 1)
	signal.Notify(c, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-c
		rs.Shutdown(context.Background())
		if processor != nil {
			processor.Stop()
		}
		w.Done()
	}()

	daemon.SdNotify(false, "READY=1")

	go func() {
		interval, err := daemon.SdWatchdogEnabled(false)
		if err != nil || interval == 0 {
			return
		}
		for {
			daemon.SdNotify(false, "WATCHDOG=1")
			time.Sleep(interval / 3)
		}
	}()

	defer NotifySystemd("STOPPING=1")
	if processor != nil {
		processor.Start()
	}
	w.Wait()
}

func NotifySystemd(msg string) {
	_, err := daemon.SdNotify(false, msg)
	if err != nil {
		log.LoggerWContext(context.Background(), fmt.Sprintf("Error sending systemd ready notification: %s", err.Error()))
	}
}
