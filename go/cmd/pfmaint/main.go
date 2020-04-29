package main

import (
	"fmt"
	"github.com/robfig/cron/v3"
	"os"
	"sync"
	//	"github.com/coreos/go-systemd/daemon"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/maint"
	"os/signal"
	"syscall"
)

func main() {
	log.SetProcessName("pfmaint")
	c := cron.New(cron.WithSeconds())
	for _, job := range getJobs() {
		id, err := c.AddJob(job.Spec(), job)
		if err != nil {
			fmt.Printf("Error: %s\n", err.Error())
		} else {
			fmt.Printf("Id:%v\n", id)
		}
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

func getJobs() []maint.Job {
	return []maint.Job{
		maint.NewPfmonJob("acct_maintenance", "@every 1m"),
	}
}
