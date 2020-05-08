package main

import (
	"github.com/robfig/cron/v3"
	"os"
	"sync"
	//	"github.com/coreos/go-systemd/daemon"
	"context"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/maint"
	"os/signal"
	"syscall"
)

func main() {
	log.SetProcessName("pfmaint")
	ctx := context.Background()
	logger := log.LoggerWContext(ctx)
	c := cron.New(cron.WithSeconds())
	for _, setupConfig := range maint.GetConfiguredJobs() {
		id := c.Schedule(setupConfig.Schedule, setupConfig.Job)
		logger.Info("Job id %d", id)
	}
	w := sync.WaitGroup{}
	w.Add(1)
	c.Start()
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-ch
		w.Done()
	}()
	w.Wait()
	doneCtx := c.Stop()
	<-doneCtx.Done()
}
