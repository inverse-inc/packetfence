package main

import (
	"context"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"sort"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/coreos/go-systemd/daemon"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/file_paths"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/pfqueueclient"
	"github.com/redis/go-redis/v9"
)

const PFQUEUE_WEIGHTS = "QueueWeights"

func main() {
	log.SetProcessName("pfqueue")
	ctx := log.LoggerNewContext(context.Background())
	backend := NewBackendManager(ctx)
	if err := backend.Start(); err != nil {
		logErrorf(ctx, "Failed to start pfqueue-backend: %s", err.Error())
		os.Exit(1)
	}

	systemdStart()
	c := make(chan os.Signal, 1)
	signal.Notify(c, syscall.SIGINT, syscall.SIGTERM)
	qw := buildQueueWorkers()
	fmt.Println("Starting")
	go qw.Run()
	<-c
	NotifySystemd("STOPPING=1")
	// Stop the backend monitor first so it doesn't restart the backend
	// process when systemd sends SIGTERM to the entire cgroup
	backend.Stop()
	qw.Stop()
}

type BackendManager struct {
	ctx    context.Context
	stopCh chan struct{}
	doneCh chan struct{}
}

func NewBackendManager(ctx context.Context) *BackendManager {
	return &BackendManager{
		ctx:    ctx,
		stopCh: make(chan struct{}),
		doneCh: make(chan struct{}),
	}
}

func (bm *BackendManager) Start() error {
	cmd, err := bm.startProcess()
	if err != nil {
		return err
	}

	go bm.monitor(cmd)
	return nil
}

func (bm *BackendManager) startProcess() (*exec.Cmd, error) {
	backendPath := file_paths.PF_DIR + "/sbin/pfqueue-backend"
	cmd := exec.Command(backendPath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	// Set the child in its own process group so we can signal it cleanly
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("starting pfqueue-backend: %w", err)
	}

	logInfof(bm.ctx, "Started pfqueue-backend (pid %d)", cmd.Process.Pid)

	// Wait for the backend socket to become available
	socketPath := file_paths.PFQUEUE_BACKEND_SOCKET
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("unix", socketPath, 100*time.Millisecond)
		if err == nil {
			conn.Close()
			logInfof(bm.ctx, "pfqueue-backend socket is ready")
			return cmd, nil
		}
		time.Sleep(100 * time.Millisecond)
	}

	// Timeout waiting for socket - kill the process and report error
	cmd.Process.Kill()
	cmd.Wait()
	return nil, fmt.Errorf("timed out waiting for pfqueue-backend socket at %s", socketPath)
}

func (bm *BackendManager) isStopping() bool {
	select {
	case <-bm.stopCh:
		return true
	default:
		return false
	}
}

// monitor is the sole goroutine that calls cmd.Wait() on the active process.
// Stop() signals via stopCh; monitor handles SIGTERM and the actual Wait.
func (bm *BackendManager) monitor(cmd *exec.Cmd) {
	defer close(bm.doneCh)
	for {
		waitDone := make(chan error, 1)
		go func() {
			waitDone <- cmd.Wait()
		}()

		select {
		case err := <-waitDone:
			if bm.isStopping() {
				return
			}
			logWarnf(bm.ctx, "pfqueue-backend (pid %d) exited unexpectedly: %v, restarting", cmd.Process.Pid, err)
		case <-bm.stopCh:
			cmd.Process.Signal(syscall.SIGTERM)
			select {
			case <-waitDone:
			case <-time.After(30 * time.Second):
				logWarnf(bm.ctx, "pfqueue-backend did not stop gracefully, killing")
				cmd.Process.Kill()
				<-waitDone
			}
			return
		}

		// Retry startProcess with backoff until it succeeds or stop is signaled
		backoff := time.Second
		for {
			select {
			case <-time.After(backoff):
			case <-bm.stopCh:
				return
			}

			newCmd, err := bm.startProcess()
			if err != nil {
				logErrorf(bm.ctx, "Failed to restart pfqueue-backend: %s, retrying in %s", err.Error(), backoff)
				if backoff < 30*time.Second {
					backoff *= 2
				}
				continue
			}

			cmd = newCmd
			break
		}
	}
}

// Stop signals the monitor to shut down and waits for it to finish.
// The monitor handles sending SIGTERM to the current backend process.
func (bm *BackendManager) Stop() {
	close(bm.stopCh)
	<-bm.doneCh
	logInfof(bm.ctx, "pfqueue-backend stopped")
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
		qw.waiter.Add(1)
		go func(q string, r *atomic.Bool) {
			defer qw.waiter.Done()
			r.Store(true)
			qw.runSingleWorkerQueue(q, r)
		}(q, r)
	}

	for i := 0; i < qw.WorkerCount; i++ {
		r := &atomic.Bool{}
		qw.runningBooleans = append(qw.runningBooleans, r)
		qw.waiter.Add(1)
		go func(r *atomic.Bool) {
			defer qw.waiter.Done()
			r.Store(true)
			qw.runMultiWorkerQueue(r)
		}(r)
	}

	for _, dq := range qw.DelayedWorkerQueues {
		r := &atomic.Bool{}
		qw.runningBooleans = append(qw.runningBooleans, r)
		qw.waiter.Add(1)
		go func(r *atomic.Bool, dq pfqueueclient.DelayedQueue) {
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
