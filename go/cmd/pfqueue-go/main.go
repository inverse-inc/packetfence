package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"sort"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/coreos/go-systemd/daemon"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/redis/go-redis/v9"
)

const PFQUEUE_WEIGHTS = "QueueWeights"

func main() {
	log.SetProcessName("pfqueue")
	systemdStart()
	c := make(chan os.Signal, 1)
	signal.Notify(c, syscall.SIGINT, syscall.SIGTERM)
	qw := buildQueueWorkers()
	fmt.Println("Starting")
	go qw.Run()
	<-c
	qw.Stop()
	defer NotifySystemd("STOPPING=1")
}

type DelayedQueue struct {
	DelayQueue, SubmitQueue string
}

type QueueWeight struct {
	Weight    int
	QueueName string
}

type WorkerQueue struct {
}

type QueueWorkers struct {
	redis               *redis.Client
	SingleWorkerQueues  []string
	QueuesWeighted      []string
	DelayedWorkerQueues []DelayedQueue
	WorkerCount         int
	waiter              sync.WaitGroup
	runningBooleans     []*atomic.Bool
}

func (qw *QueueWorkers) runSingleWorkerQueue(q string, r *atomic.Bool) {
	for r.Load() {
		time.Sleep(5 * time.Second)
		fmt.Printf("Processing %s\n", q)
	}
	qw.waiter.Done()
}

func (qw *QueueWorkers) runMultiWorkerQueue(r *atomic.Bool) {
	for r.Load() {
		time.Sleep(5 * time.Second)
		fmt.Printf("Multiqueues \n")
	}
	qw.waiter.Done()
}

func (qw *QueueWorkers) Stop() {
	for _, b := range qw.runningBooleans {
		b.Store(false)
	}
	qw.waiter.Done()
	qw.waiter.Wait()
}

func (qw *QueueWorkers) Run() {
	qw.waiter.Add(1)
	for _, q := range qw.SingleWorkerQueues {
		r := &atomic.Bool{}
		qw.runningBooleans = append(qw.runningBooleans, r)
		go func(q string, r *atomic.Bool) {
			qw.waiter.Add(1)
			r.Store(true)
			qw.runSingleWorkerQueue(q, r)
		}(q, r)
	}

	for i := 0; i < qw.WorkerCount; i++ {
		r := &atomic.Bool{}
		qw.runningBooleans = append(qw.runningBooleans, r)
		go func(r *atomic.Bool) {
			qw.waiter.Add(1)
			r.Store(true)
			qw.runMultiWorkerQueue(r)
		}(r)
	}
	qw.waiter.Wait()
}

func buildQueueWorkers() *QueueWorkers {
	var pfqueue pfconfigdriver.PfQueueConfig
	ctx := context.Background()
	pfconfigdriver.FetchDecodeSocket(ctx, &pfqueue)
	w := &QueueWorkers{
		redis: redis.NewClient(&redis.Options{
			Addr:     pfqueue.Consumer.RedisArgs.Server,
			Password: "", // no password set
			DB:       0,  // use default DB
		}),
	}

	weights := []QueueWeight{}
	for _, q := range pfqueue.Queues {
		if skipQueue(&q) {
			continue
		}

		queueName := "Queue:" + q.Name
		delayedName := "Delayed:" + q.Name
		if q.Weight > 0 {
			weights = append(weights, QueueWeight{q.Weight, queueName})
		}

		for i := 0; i < q.Workers; i++ {
			w.SingleWorkerQueues = append(w.SingleWorkerQueues, queueName)
		}

		w.DelayedWorkerQueues = append(w.DelayedWorkerQueues, DelayedQueue{queueName, delayedName})
	}

	if len(weights) > 0 {
		sort.Slice(weights, func(i, j int) bool {
			return weights[i].Weight < weights[j].Weight
		})
		w.QueuesWeighted = distributeQueues(weights)
		pipeliner := w.redis.Pipeline()
		pipeliner.Del(ctx, PFQUEUE_WEIGHTS)
		pipeliner.LPush(ctx, PFQUEUE_WEIGHTS, ToAnyArray(w.QueuesWeighted)...)
		pipeliner.Exec(ctx)
	}

	return w
}

func ToAnyArray[T any](a []T) []interface{} {
	out := make([]interface{}, 0, len(a))
	for _, i := range a {
		out = append(out, i)
	}

	return out
}

func distributeQueues(weights []QueueWeight) []string {
	queues := []string{}
	running := true
	for running {
		running = false
		for i := 0; i < len(weights); i++ {
			if weights[i].Weight > 0 {
				weights[i].Weight = weights[i].Weight - 1
				queues = append(queues, weights[i].QueueName)
				running = true
			}
		}
	}

	return queues
}

func skipQueue(q *pfconfigdriver.Queue) bool {
	return false
}

func NotifySystemd(msg string) {
	_, err := daemon.SdNotify(false, msg)
	if err != nil {
		log.LoggerWContext(context.Background(), fmt.Sprintf("Error sending systemd ready notification: %s", err.Error()))
	}
}

func systemdStart() {
	daemon.SdNotify(false, "READY=1")

	interval, err := daemon.SdWatchdogEnabled(false)
	if err != nil || interval == 0 {
		return
	}

	go func() {
		for {
			daemon.SdNotify(false, "WATCHDOG=1")
			time.Sleep(interval / 3)
		}
	}()
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
