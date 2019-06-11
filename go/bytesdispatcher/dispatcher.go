package bytesdispatcher

import (
	"github.com/inverse-inc/packetfence/go/bytearraypool"
)

type BytesHandler func([]byte)

type Worker struct {
	WorkerPool    chan chan []byte
	JobChannel    chan []byte
	bytesHandler  BytesHandler
	byteArrayPool *bytearraypool.ByteArrayPool
	StopChannel   chan struct{}
}

func NewWorker(workerPool chan chan []byte, bytesHandler BytesHandler, byteArrayPool *bytearraypool.ByteArrayPool) *Worker {
	return &Worker{
		WorkerPool:    workerPool,
		bytesHandler:  bytesHandler,
		byteArrayPool: byteArrayPool,
		JobChannel:    make(chan []byte),
		StopChannel:   make(chan struct{}),
	}
}

func (w *Worker) HandleBytes(bytes []byte) {
	defer w.byteArrayPool.Put(bytes)
	w.bytesHandler(bytes)
}

func (w *Worker) Start() {
	go func() {

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
	QuitChannels  []chan struct{}
}

func NewDispatcher(maxWorkers, jobQueueSize int, bytesHandler BytesHandler, byteArrayPool *bytearraypool.ByteArrayPool) *Dispatcher {
	return &Dispatcher{
		maxWorkers:    maxWorkers,
		bytesHandler:  bytesHandler,
		byteArrayPool: byteArrayPool,
		JobQueue:      make(chan []byte, jobQueueSize),
		WorkerPool:    make(chan chan []byte, maxWorkers),
		QuitChannels:  make([]chan struct{}, maxWorkers),
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
	for i := 0; i < d.maxWorkers; i++ {
		worker := NewWorker(d.WorkerPool, d.bytesHandler, d.byteArrayPool)
		worker.Start()
	}

	go d.dispatch()
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
