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
	"github.com/inverse-inc/go-utils/sharedutils"
	maint "github.com/inverse-inc/packetfence/go/cron"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/netresearch/go-cron"
)

func watchConfigChanges(ctx context.Context, c *cron.Cron, logger log.PfLogger, waiter *sync.WaitGroup) {
	defer waiter.Done()
	lastStatus := make(map[string]bool)

	// Initialize with current config
	if config := maint.GetMaintenanceConfig(ctx); config != nil {
		for name, v := range config {
			data, ok := v.(map[string]interface{})
			if !ok {
				continue
			}
			status, ok := data["status"].(string)
			if !ok {
				continue
			}
			lastStatus[name] = sharedutils.IsEnabled(status)
		}
	}

	ticker := time.NewTicker(time.Minute)
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			config := maint.GetMaintenanceConfig(ctx)
			if config == nil {
				continue
			}

			for name, v := range config {
				data, ok := v.(map[string]interface{})
				if !ok {
					continue
				}
				status, ok := data["status"].(string)
				if !ok {
					continue
				}

				enabled := sharedutils.IsEnabled(status)
				prev, existed := lastStatus[name]
				lastStatus[name] = enabled

				if !existed {
					continue
				}

				if prev && !enabled {
					logger.Info(fmt.Sprintf("Job '%s' status changed to disabled, pausing", name))
					if err := c.PauseEntryByName(name); err != nil {
						logger.Error(fmt.Sprintf("Error pausing job '%s': %v", name, err))
					}
				} else if !prev && enabled {
					logger.Info(fmt.Sprintf("Job '%s' status changed to enabled, resuming", name))
					if err := c.ResumeEntryByName(name); err != nil {
						logger.Error(fmt.Sprintf("Error resuming job '%s': %v", name, err))
					}
				}
			}
		}
	}
}

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

type pfCronJobWrapper struct {
	logger log.PfLogger
	job    cron.Job
	ch     chan struct{}
}

func (p *pfCronJobWrapper) Run() {
	p.RunWithContext(context.Background())
}

func runJob(ctx context.Context, j cron.Job) {
	if jc, ok := j.(cron.JobWithContext); ok {
		jc.RunWithContext(ctx)
	} else {
		j.Run()
	}
}

func (p *pfCronJobWrapper) RunWithContext(ctx context.Context) {
	name, local := "unnamed job", false
	if j, ok := p.job.(maint.JobSetupConfig); ok {
		name, local = j.Name(), j.ForceLocal()
	}

	defer func() {
		if r := recover(); r != nil {
			p.logger.Error(fmt.Sprintf("Job %s panic: %s", name, r))
		}
	}()

	if !local && atomic.LoadUint32(&processJobs) == 0 {
		p.logger.Info("Not processing " + name)
		return
	}

	select {
	case v := <-p.ch:
		defer func() { p.ch <- v }()
		p.logger.Info("Running " + name)
		runJob(ctx, p.job)

	default:
		p.logger.Info(" Skipped " + name)
	}
}

func pfCronWrapper(logger log.PfLogger) cron.JobWrapper {
	return func(j cron.Job) cron.Job {
		ch := make(chan struct{}, 1)
		ch <- struct{}{}
		return &pfCronJobWrapper{
			job:    j,
			ch:     ch,
			logger: logger,
		}
	}
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
	c := cron.New(cron.WithParser(
		cron.NewParser(
			cron.SecondOptional|cron.Minute|cron.Hour|cron.Dom|cron.Month|cron.Dow|cron.Descriptor,
		)),
		cron.WithChain(pfCronWrapper(logger)),
	)

	triggeredJobs := []string{}
	for _, job := range maint.GetConfiguredJobs(maint.GetMaintenanceConfig(ctx)) {
		name := job.Name()
		schedule := job.Schedule()
		id, err := c.ScheduleJob(
			schedule,
			job,
			job.JobOptions()...,
		)
		if err != nil {
			logger.Error(fmt.Sprintf("Error creating cron job %s: %v", job.Name(), err))
			continue
		}

		if _, ok := schedule.(*cron.TriggeredSchedule); ok && job.Enabled() {
			triggeredJobs = append(triggeredJobs, name)
		}

		logger.Info(fmt.Sprintf("task '%s' created with id %d with schedule of %s", job.Name(), int64(id), job.ScheduleSpec()))
	}

	w := sync.WaitGroup{}
	w.Add(2)
	NotifySystemd("READY=1")
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	watchCtx, cancel := context.WithCancel(context.Background())
	go func() {
		<-ch
		cancel()
		w.Done()
	}()
	go setProcessing()
	go watchConfigChanges(watchCtx, c, logger, &w)
	c.Start()
	for _, j := range triggeredJobs {
		c.TriggerEntryByName(j)
	}
	w.Wait()
	doneCtx := c.Stop()
	<-doneCtx.Done()
	NotifySystemd("STOPPING=1")
}
