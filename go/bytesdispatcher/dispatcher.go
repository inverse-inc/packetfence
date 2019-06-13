package bytesdispatcher

import (
	"github.com/inverse-inc/packetfence/go/bytearraypool"
	"sync"
)

type BytesHandler interface {
    HandleBytes([]byte)
}

type BytesHandlerFunc func([]byte)

func (f BytesHandlerFunc) HandleBytes(bytes []byte) {
    f(bytes)
}

type Worker struct {
	WorkerPool    chan chan []byte
	JobChannel    chan []byte
	bytesHandler  BytesHandler
	byteArrayPool *bytearraypool.ByteArrayPool
	StopChannel   chan struct{}
	waitGroup     *sync.WaitGroup
}

func NewWorker(workerPool chan chan []byte, bytesHandler BytesHandler, byteArrayPool *bytearraypool.ByteArrayPool, waitGroup *sync.WaitGroup) *Worker {
	w := &Worker{}
	InitWorker(w, workerPool, bytesHandler, byteArrayPool, waitGroup)
	return w
}

func InitWorker(w *Worker, workerPool chan chan []byte, bytesHandler BytesHandler, byteArrayPool *bytearraypool.ByteArrayPool, waitGroup *sync.WaitGroup) {
	w.WorkerPool = workerPool
	w.bytesHandler = bytesHandler
	w.byteArrayPool = byteArrayPool
	w.JobChannel = make(chan []byte)
	w.StopChannel = make(chan struct{})
	w.waitGroup = waitGroup
}

func (w *Worker) HandleBytes(bytes []byte) {
	defer w.byteArrayPool.Put(bytes)
	w.bytesHandler.HandleBytes(bytes)
}

func (w *Worker) Start() {
	go func() {
		defer w.waitGroup.Done()
	LOOP:
		for {
			// register the current worker into the worker queue.
			w.WorkerPool <- w.JobChannel

			select {
			case job := <-w.JobChannel:
				w.HandleBytes(job)

			case <-w.StopChannel:
				// we have received a signal to stop
				break LOOP
			}
		}

		// Handle any leftover jobs
		select {
		case job := <-w.JobChannel:
			w.HandleBytes(job)
		default:
			return
		}
	}()
}

func (w *Worker) Stop() {
	go func() {
		w.StopChannel <- struct{}{}
	}()
}

type Dispatcher struct {
	// A pool of workers channels that are registered with the dispatcher
	maxWorkers    int
	byteArrayPool *bytearraypool.ByteArrayPool
	bytesHandler  BytesHandler
	JobQueue      chan []byte
	WorkerPool    chan chan []byte
	Workers       []Worker
	waitGroup     sync.WaitGroup
}

func NewDispatcher(maxWorkers, jobQueueSize int, bytesHandler BytesHandler, byteArrayPool *bytearraypool.ByteArrayPool) *Dispatcher {
	return &Dispatcher{
		maxWorkers:    maxWorkers,
		bytesHandler:  bytesHandler,
		byteArrayPool: byteArrayPool,
		JobQueue:      make(chan []byte, jobQueueSize),
		WorkerPool:    make(chan chan []byte, maxWorkers),
	}
}

func (d *Dispatcher) SubmitJob(job []byte) {
	select {
	case d.JobQueue <- job:
	default:
		go func() {
			d.JobQueue <- job
		}()
	}
}

func (d *Dispatcher) Run() {
	// starting n number of workers
	d.Workers = make([]Worker, d.maxWorkers)
	d.waitGroup.Add(d.maxWorkers)
	for i := 0; i < d.maxWorkers; i++ {
		InitWorker(&d.Workers[i], d.WorkerPool, d.bytesHandler, d.byteArrayPool, &d.waitGroup)
		d.Workers[i].Start()
	}

	go d.dispatch()
}

func (d *Dispatcher) Stop() {
	for i := range d.Workers {
		d.Workers[i].Stop()
	}

	d.Wait()
}

func (d *Dispatcher) Wait() {
	d.waitGroup.Wait()
}

func (d *Dispatcher) dispatch() {
	for {
		select {
		// a job request has been received
		case job := <-d.JobQueue:
			select {
			// Take care of it right away
			case jobChannel := <-d.WorkerPool:
				jobChannel <- job
			// No workers available put it in a go routine
			default:
				go func(job []byte) {
					jobChannel := <-d.WorkerPool
					jobChannel <- job
				}(job)
			}
		}
	}
}
