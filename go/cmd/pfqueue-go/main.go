package main

import (
	"context"
	"errors"
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
	"github.com/inverse-inc/packetfence/go/pfqueueclient"
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

type QueueWeight struct {
	Weight    int
	QueueName string
}

type QueueWorkers struct {
	redis               *redis.Client
	SingleWorkerQueues  []string
	QueuesWeighted      []string
	DelayedWorkerQueues []pfqueueclient.DelayedQueue
	WorkerCount         int
	waiter              sync.WaitGroup
	runningBooleans     []*atomic.Bool
	currentIndex        atomic.Uint64
}

func (qw *QueueWorkers) runDelayedQueueWorker(dq pfqueueclient.DelayedQueue, r *atomic.Bool) {
	ctx := log.LoggerNewContext(context.Background())
	for r.Load() {
		dq.Run(ctx, qw.redis)
		time.Sleep(time.Millisecond * 100)
	}
}

func (qw *QueueWorkers) runSingleWorkerQueue(q string, r *atomic.Bool) {
	ctx := log.LoggerNewContext(context.Background())
	consumer, err := pfqueueclient.NewConsumer(qw.redis, q)
	if err != nil {
		return
	}

	for r.Load() {
		err := consumer.ProcessNextQueueItem(ctx, []string{q})
		if err == nil {
			continue
		}

		if errors.Is(err, redis.Nil) {
			continue
		}

		logErrorf(ctx, "Error runSingleWorkerQueue: %s", err.Error())
	}
}

func (qw *QueueWorkers) getNextWeights() []string {
	length := uint64(len(qw.QueuesWeighted))
	start := (qw.currentIndex.Add(1) - 1) % length
	nextWeights := make([]string, 0, len(qw.QueuesWeighted))
	for i := start; i < length; i++ {
		nextWeights = append(nextWeights, qw.QueuesWeighted[i])
	}

	for i := uint64(0); i < start; i++ {
		nextWeights = append(nextWeights, qw.QueuesWeighted[i])
	}

	return nextWeights
}

func (qw *QueueWorkers) runMultiWorkerQueue(r *atomic.Bool) {
	ctx := log.LoggerNewContext(context.Background())
	consumer, err := pfqueueclient.NewConsumer(qw.redis, "worker")
	if err != nil {
		return
	}

	defer consumer.Close()
	for r.Load() {
		err := consumer.ProcessNextQueueItem(ctx, qw.getNextWeights())
		if err == nil {
			continue
		}

		if errors.Is(err, redis.Nil) {
			continue
		}

		logErrorf(ctx, "Error runMultiWorkerQueue: %s", err.Error())
	}
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
			defer qw.waiter.Done()
			r.Store(true)
			qw.runSingleWorkerQueue(q, r)
		}(q, r)
	}

	for i := 0; i < qw.WorkerCount; i++ {
		r := &atomic.Bool{}
		qw.runningBooleans = append(qw.runningBooleans, r)
		go func(r *atomic.Bool) {
			qw.waiter.Add(1)
			defer qw.waiter.Done()
			r.Store(true)
			qw.runMultiWorkerQueue(r)
		}(r)
	}

	for _, dq := range qw.DelayedWorkerQueues {
		r := &atomic.Bool{}
		qw.runningBooleans = append(qw.runningBooleans, r)
		go func(r *atomic.Bool, dq pfqueueclient.DelayedQueue) {
			qw.waiter.Add(1)
			defer qw.waiter.Done()
			r.Store(true)
			qw.runDelayedQueueWorker(dq, r)
		}(r, dq)
	}
	qw.waiter.Wait()

}

func setupConnection(ctx context.Context, conn *redis.Conn) error {
	return pfqueueclient.SetupConnection(ctx, conn)
}

func credentialsProvider() (string, string) {
	return "", ""
}

func buildQueueWorkers() *QueueWorkers {
	var pfqueue pfconfigdriver.PfQueueConfig
	ctx := log.LoggerNewContext(context.Background())
	pfconfigdriver.FetchDecodeSocket(ctx, &pfqueue)
	redisClient := redis.NewClient(&redis.Options{
		Addr:                pfqueue.Consumer.RedisArgs.Server,
		DB:                  0, // use default DB
		OnConnect:           setupConnection,
		CredentialsProvider: credentialsProvider,
	})
	w := &QueueWorkers{
		redis: redisClient,
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

		w.DelayedWorkerQueues = append(
			w.DelayedWorkerQueues,
			pfqueueclient.DelayedQueue{
				SubmitQueue: queueName,
				DelayQueue:  delayedName,
				Batch:       1000,
			},
		)
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

	w.WorkerCount = pfqueue.PfQueue.Workers
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
	ctx := log.LoggerNewContext(context.Background())
	var rLimit syscall.Rlimit
	err := syscall.Getrlimit(syscall.RLIMIT_NOFILE, &rLimit)
	if err != nil {
		logErrorf(ctx, "Error Getting Rlimit: %s", err.Error())
	}

	if rLimit.Cur < rLimit.Max {
		rLimit.Cur = rLimit.Max
		err = syscall.Setrlimit(syscall.RLIMIT_NOFILE, &rLimit)
		if err != nil {
			logErrorf(ctx, "Error Getting Rlimit: %s", err.Error())
		}
	}

	err = syscall.Getrlimit(syscall.RLIMIT_NOFILE, &rLimit)
	logInfof(ctx, "File descriptor limit is: %d", rLimit.Cur)
}

func logErrorf(ctx context.Context, msg string, args ...interface{}) {
	log.LoggerWContext(ctx).Error(fmt.Sprintf(msg, args...))
}

func logWarnf(ctx context.Context, msg string, args ...interface{}) {
	log.LoggerWContext(ctx).Warn(fmt.Sprintf(msg, args...))
}

func logInfof(ctx context.Context, msg string, args ...interface{}) {
	log.LoggerWContext(ctx).Info(fmt.Sprintf(msg, args...))
}

func logDebugf(ctx context.Context, msg string, args ...interface{}) {
	log.LoggerWContext(ctx).Debug(fmt.Sprintf(msg, args...))
}
