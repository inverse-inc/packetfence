package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/coreos/go-systemd/daemon"
	"github.com/inverse-inc/packetfence/go/log"
)

var netFlowAddr = "127.0.0.1"

func main() {
	flag.Parse()
	log.SetProcessName("pfacct")
	increaseFileLimit()

	pfacct := NewPfAcct()
	w := sync.WaitGroup{}
	rs := pfacct.radiusListen(&w)
	/*
		dispatcher := pfacct.Dispatcher
		dispatcher.Run()
	*/
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
		// dispatcher.Stop()
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

func init() {
	flag.StringVar(&netFlowAddr, "netflow-ipaddress", "127.0.0.1", "IP Address netflow processor listens on")
}

func NotifySystemd(msg string) {
	_, err := daemon.SdNotify(false, msg)
	if err != nil {
		log.LoggerWContext(context.Background(), fmt.Sprintf("Error sending systemd ready notification: %s", err.Error()))
	}
}

func increaseFileLimit() {
	var rLimit syscall.Rlimit
	err := syscall.Getrlimit(syscall.RLIMIT_NOFILE, &rLimit)
	if err != nil {
		log.LoggerWContext(context.Background()).Error("Error Getting Rlimit: " + err.Error())
	}

	if rLimit.Cur < rLimit.Max {
		rLimit.Cur = rLimit.Max
		err = syscall.Setrlimit(syscall.RLIMIT_NOFILE, &rLimit)
		if err != nil {
			log.LoggerWContext(context.Background()).Warn("Error Setting Rlimit:" + err.Error())
		}
	}

	err = syscall.Getrlimit(syscall.RLIMIT_NOFILE, &rLimit)
	log.LoggerWContext(context.Background()).Info(fmt.Sprintf("File descriptor limit is: %d", rLimit.Cur))
}
