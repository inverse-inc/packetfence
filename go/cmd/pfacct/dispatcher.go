package main

import (
	"sync"
)

type Work func()

// BytesHandler an interface for handling bytes
type BytesHandler interface {
	HandleBytes([]byte)
}

// The BytesHandlerFunc type is an adapter to allow the use of
// ordinary functions as a []byte handlers. If f is a function
// with the appropriate signature, BytesHandlerFunc(bytes) is a
// Handler that calls f.
type BytesHandlerFunc func([]byte)

// HandleBytes calls f(bytes)
func (f BytesHandlerFunc) HandleBytes(bytes []byte) {
	f(bytes)
}

type worker struct {
	workerPool  chan<- chan Work
	jobChannel  chan Work
	stopChannel chan struct{}
	waitGroup   *sync.WaitGroup
}

func initWorker(w *worker, workerPool chan<- chan Work, waitGroup *sync.WaitGroup) {
	w.workerPool = workerPool
	w.jobChannel = make(chan Work)
	w.stopChannel = make(chan struct{})
	w.waitGroup = waitGroup
}

func (w *worker) start() {
	go func() {
		defer w.waitGroup.Done()
	LOOP:
		for {
			// register the current worker into the worker queue.
			w.workerPool <- w.jobChannel

			select {
			case job := <-w.jobChannel:
				job()

			case <-w.stopChannel:
				// we have received a signal to stop
				break LOOP
			}
		}

		// Handle any leftover jobs
		select {
		case job := <-w.jobChannel:
			job()
		default:
			return
		}
	}()
}

func (w *worker) stop() {
	go func() {
		w.stopChannel <- struct{}{}
	}()
}

// Dispatcher dispatches work to a set of workers
type Dispatcher struct {
	// A pool of workers channels that are registered with the dispatcher
	maxWorkers int
	jobQueue   chan Work
	workerPool chan chan Work
	workers    []worker
	waitGroup  sync.WaitGroup
}

// NewDispatcher create a new Dispatcher
func NewDispatcher(maxWorkers, jobQueueSize int) *Dispatcher {
	return &Dispatcher{
		maxWorkers: maxWorkers,
		jobQueue:   make(chan Work, jobQueueSize),
		workerPool: make(chan chan Work, maxWorkers),
	}
}

// SubmitJob submit a byte array to be processed
func (d *Dispatcher) SubmitJob(job Work) {
	select {
	case d.jobQueue <- job:
	default:
		go func() {
			d.jobQueue <- job
		}()
	}
}

// Run the dispatcher
func (d *Dispatcher) Run() {
	// starting n number of workers
	d.workers = make([]worker, d.maxWorkers)
	d.waitGroup.Add(d.maxWorkers)
	for i := 0; i < d.maxWorkers; i++ {
		initWorker(&d.workers[i], d.workerPool, &d.waitGroup)
		d.workers[i].start()
	}

	go d.dispatch(d.jobQueue, d.workerPool)
}

// Stop the dispatcher
func (d *Dispatcher) Stop() {
	for i := range d.workers {
		d.workers[i].stop()
	}

	d.Wait()
}

// Wait for all the workers to be finished
func (d *Dispatcher) Wait() {
	d.waitGroup.Wait()
}

func (d *Dispatcher) dispatch(jobQueue <-chan Work, workerPool <-chan chan Work) {
	for {
		select {
		// a job request has been received
		case job := <-jobQueue:
			select {
			// Take care of it right away
			case jobChannel := <-workerPool:
				jobChannel <- job
			// No workers available put it in a go routine
			default:
				go func(job Work) {
					jobChannel := <-workerPool
					jobChannel <- job
				}(job)
			}
		}
	}
}
