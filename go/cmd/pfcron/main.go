package main

import (
	"context"
	"fmt"
	"github.com/coreos/go-systemd/daemon"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/maint"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/robfig/cron/v3"
	"net"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
)

func setProcessing() {
	var Management pfconfigdriver.ManagementNetwork
	ctx := context.Background()
	pfconfigdriver.FetchDecodeSocket(ctx, &Management)
	for {
		if isMaster(ctx, &Management) {
			atomic.StoreUint32(&processJobs, 1)
		} else {
			atomic.StoreUint32(&processJobs, 0)
		}

		time.Sleep(1 * time.Minute)
	}
}

func isMaster(ctx context.Context, management *pfconfigdriver.ManagementNetwork) bool {
	if pfconfigdriver.GetClusterSummary(ctx).ClusterEnabled == 1 {
		var keyConfCluster pfconfigdriver.NetInterface
		keyConfCluster.PfconfigNS = "config::Pf(CLUSTER," + pfconfigdriver.FindClusterName(ctx) + ")"

		keyConfCluster.PfconfigHashNS = "interface " + management.Int
		pfconfigdriver.FetchDecodeSocket(ctx, &keyConfCluster)
		// Nothing in keyConfCluster.Ip so we are not in cluster mode
		if keyConfCluster.Ip == "" {
			return true
		}

		eth, _ := net.InterfaceByName(management.Int)
		addresses, _ := eth.Addrs()

		for _, address := range addresses {
			IP, _, _ := net.ParseCIDR(address.String())
			clusterIp := net.ParseIP(keyConfCluster.Ip)
			if IP.Equal(clusterIp) {
				return true
			}
		}
		return false
	}

	return true
}

var processJobs uint32 = 1

func wrapJob(logger log.PfLogger, j maint.JobSetupConfig) cron.Job {
	var ch = make(chan struct{}, 1)
	ch <- struct{}{}
	return cron.FuncJob(func() {
		if atomic.LoadUint32(&processJobs) == 0 {
			return
		}

		defer func() {
			if r := recover(); r != nil {
				logger.Error(fmt.Sprintf("Job %s panic: %s", j.Name(), r))
			}
		}()

		select {
		case v := <-ch:
			j.Run()
			ch <- v
		default:
			logger.Info(j.Name() + " Skipped")
		}
	})
}

func mergeArgs(config, args map[string]interface{}) map[string]interface{} {
	newArgs := make(map[string]interface{})
	for k, v := range config {
		newArgs[k] = v
	}

	for k, v := range args {
		newArgs[k] = v
	}

	return newArgs
}

func runJobNow(name string, additionalArgs map[string]interface{}) int {
	jobsConfig := maint.GetMaintenanceConfig()
	if config, found := jobsConfig[name]; found {
		job := maint.GetJob(name, mergeArgs(config.(map[string]interface{}), additionalArgs))
		if job != nil {
			job.Run()
			return 0
		}

		fmt.Printf("Error creating job '%s'\n", name)
	} else {
		fmt.Printf("'%s' is not a valid job task\n", name)
	}

	return 1
}

func makeArgs(args []string) (map[string]interface{}, error) {
	config := make(map[string]interface{})
	for _, arg := range args {
		pair := strings.SplitN(arg, "=", 2)
		if len(pair) != 2 {
			return nil, fmt.Errorf("'%s' is incorrectly formatted\n", arg)
		}

		config[pair[0]] = pair[1]
	}

	return config, nil
}

func NotifySystemd(msg string) {
	_, err := daemon.SdNotify(false, msg)
	if err != nil {
		log.LoggerWContext(context.Background()).Error(fmt.Sprintf("Error sending systemd ready notification: %s", err.Error()))
	}
}

func main() {
	log.SetProcessName("pfcron")
	if len(os.Args) > 1 {
		jobName := os.Args[1]
		code := 0
		if additionalArgs, err := makeArgs(os.Args[2:]); err != nil {
			fmt.Printf("%s\n", err.Error())
			code = 1
		} else {
			code = runJobNow(jobName, additionalArgs)
			fmt.Printf("task %s finished\n", jobName)
		}
		os.Exit(code)
	}

	ctx := context.Background()
	logger := log.LoggerWContext(ctx)
	c := cron.New(cron.WithSeconds())
	for _, job := range maint.GetConfiguredJobs(maint.GetMaintenanceConfig()) {
		id := c.Schedule(job.Schedule(), wrapJob(logger, job))
		logger.Info("Job id " + strconv.FormatInt(int64(id), 10))
	}

	w := sync.WaitGroup{}
	w.Add(1)
	NotifySystemd("READY=1")
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-ch
		w.Done()
	}()
	go setProcessing()
	c.Start()
	w.Wait()
	doneCtx := c.Stop()
	<-doneCtx.Done()
	NotifySystemd("STOPPING=1")
}
