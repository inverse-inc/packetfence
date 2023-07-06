package main

import (
	"context"
	"fmt"
	"net"
	"os"
	"os/signal"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/coreos/go-systemd/daemon"
	"github.com/inverse-inc/go-utils/log"
	maint "github.com/inverse-inc/packetfence/go/cron"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/robfig/cron/v3"
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
		clusterIp := net.ParseIP(keyConfCluster.Ip)

		for _, address := range addresses {
			IP, _, _ := net.ParseCIDR(address.String())
			if IP.Equal(clusterIp) {
				return true
			}
		}
		return false
	}

	return true
}

var processJobs uint32 = 1

func wrapJob(logger log.PfLogger, j string, l bool) cron.Job {
	var ch = make(chan struct{}, 1)
	ch <- struct{}{}
	return cron.FuncJob(func() {
		defer func() {
			if r := recover(); r != nil {
				logger.Error(fmt.Sprintf("Job %s panic: %s", j, r))
			}
		}()

		if atomic.LoadUint32(&processJobs) == 0 && l == false {
			logger.Info("Not processing " + j)
			return
		}

		select {
		case v := <-ch:
			if job := maint.GetJob(j, maint.GetMaintenanceConfig(context.Background())); job != nil {
				logger.Info("Running " + j)
				job.Run()
			} else {
				logger.Error("Cannot create job " + j)
			}
			ch <- v
		default:
			logger.Info(" Skipped " + j)
		}
	})
}

func runJobNow(name string, additionalArgs map[string]interface{}) int {
	jobsConfig := maint.GetMaintenanceConfig(context.Background())
	if config, found := jobsConfig[name]; found {
		job := maint.BuildJob(
			name,
			maint.MergeArgs(
				config.(map[string]interface{}),
				additionalArgs,
			),
		)
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
		additionalArgs, err := makeArgs(os.Args[2:])
		if err != nil {
			fmt.Printf("%s\n", err.Error())
			os.Exit(1)
			return
		}

		code = runJobNow(jobName, additionalArgs)
		if code == 0 {
			fmt.Printf("task %s finished\n", jobName)
		}

		os.Exit(code)
		return
	}

	ctx := context.Background()
	logger := log.LoggerWContext(ctx)
	c := cron.New(cron.WithParser(cron.NewParser(
		cron.SecondOptional | cron.Minute | cron.Hour | cron.Dom | cron.Month | cron.Dow | cron.Descriptor,
	)))

	for _, job := range maint.GetConfiguredJobs(maint.GetMaintenanceConfig(ctx)) {
		id := c.Schedule(job.Schedule(), wrapJob(logger, job.Name(), job.ForceLocal()))
		logger.Info(fmt.Sprintf("task '%s' created with id %d with schedule of %s", job.Name(), int64(id), job.ScheduleSpec()))
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
