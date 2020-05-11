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
	"strconv"
	"syscall"
)

func wrapJob(logger log.PfLogger, j maint.JobSetupConfig) cron.Job {
	var ch = make(chan struct{}, 1)
	ch <- struct{}{}
	return cron.FuncJob(func() {
		select {
		case v := <-ch:
			j.Run()
			ch <- v
		default:
			logger.Info(j.Name() + " Skipped")
		}
	})
}

func main() {
	log.SetProcessName("pfmaint")
	ctx := context.Background()
	logger := log.LoggerWContext(ctx)
	c := cron.New(cron.WithSeconds())
	for _, job := range maint.GetConfiguredJobs() {
		id := c.Schedule(job.Schedule(), wrapJob(logger, job))
		logger.Info("Job id " + strconv.FormatInt(int64(id), 10))
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
