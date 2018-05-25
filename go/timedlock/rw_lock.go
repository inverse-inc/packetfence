package timedlock

import (
	"fmt"
	"runtime"
	"sync"
	"time"
)

var timerPool = &sync.Pool{}
var chanPool = &sync.Pool{
	New: func() interface{} {
		return make(chan int)
	},
}

type RWLock struct {
	rwMutex      *sync.RWMutex
	doneChans    map[uint64]chan int
	internalLock *sync.Mutex

	// A counter to track the amount of allocated locks for providing the next ID
	c uint64

	// When defined, failures in the locks will be sent to that channel
	// Defaults to being nil, so it needs to be initialized
	LockFailures chan uint64

	// The timeout for Lock operations
	Timeout time.Duration

	// The timeout for RLock operations
	RTimeout time.Duration

	// Whether or not this should panic on timeouts
	// Otherwise, it will just release the lock
	Panic bool

	// Whether or not the errors should be printed
	PrintErrors bool

	// tracks whether or not this is RW locked
	isLocked bool
}

func NewRWLock() *RWLock {
	return &RWLock{
		rwMutex:      &sync.RWMutex{},
		Timeout:      10 * time.Second,
		RTimeout:     10 * time.Second,
		internalLock: &sync.Mutex{},
		Panic:        true,
		PrintErrors:  false,
	}
}

func (l *RWLock) getDoneChan() (uint64, chan int) {
	l.internalLock.Lock()
	defer l.internalLock.Unlock()

	l.c++
	u := l.c
	if l.doneChans == nil {
		l.doneChans = make(map[uint64]chan int)
	}

	if _, ok := l.doneChans[u]; ok {
		panic(fmt.Sprintf("Done channel already exists for identifier %d", u))
	}

	c := chanPool.Get().(chan int)

	l.doneChans[u] = c

	return u, l.doneChans[u]
}

func (l *RWLock) deleteChan(id uint64) {
	l.internalLock.Lock()
	defer l.internalLock.Unlock()
	chanPool.Put(l.doneChans[id])
	delete(l.doneChans, id)
}

func (l *RWLock) sendDoneSig(id uint64) {
	l.internalLock.Lock()
	defer l.internalLock.Unlock()
	l.doneChans[id] <- 1
}

func (l *RWLock) getTimer(d time.Duration) *time.Timer {
	o := timerPool.Get()
	if o == nil {
		return time.NewTimer(d)
	} else {
		t := o.(*time.Timer)
		t.Reset(d)
		return t
	}
}

func (l *RWLock) releaseTimer(t *time.Timer) {
	t.Stop()
	timerPool.Put(t)
}

func (l *RWLock) Lock() uint64 {
	id, doneChan := l.getDoneChan()

	stack := make([]uintptr, 20)
	runtime.Callers(0, stack)

	go func() {
		timeoutTimer := l.getTimer(l.Timeout)
		defer l.releaseTimer(timeoutTimer)
		select {
		case <-timeoutTimer.C:
			l.internalLock.Lock()
			if l.isLocked {
				l.rwMutex.Unlock()
			}
			l.internalLock.Unlock()

			l.handleTimeout(id, "Timeout obtaining or releasing lock that came from: \n", stack)
		case <-doneChan:
			timeoutTimer.Stop()
			l.deleteChan(id)
		}
	}()

	l.rwMutex.Lock()

	l.internalLock.Lock()
	l.isLocked = true
	l.internalLock.Unlock()
	return id
}

func (l *RWLock) Unlock(id uint64) {
	l.sendDoneSig(id)
	l.internalLock.Lock()
	if l.isLocked {
		l.rwMutex.Unlock()
	}
	l.isLocked = false
	l.internalLock.Unlock()
}

func (l *RWLock) handleTimeout(id uint64, msg string, stack []uintptr) {
	stackStr := ""
	frames := runtime.CallersFrames(stack)
	for {
		frame, more := frames.Next()
		if frame.Function == "" {
			break
		}
		stackStr += fmt.Sprintf("%s\n\t%s:%d\n", frame.Function, frame.File, frame.Line)
		if !more {
			break
		}
	}

	l.deleteChan(id)
	if l.LockFailures != nil {
		l.LockFailures <- id
	}
	msg = msg + stackStr
	if l.Panic {
		panic(msg)
	} else if l.PrintErrors {
		fmt.Println(msg)
	}
}

func (l *RWLock) RLock() uint64 {
	id, doneChan := l.getDoneChan()

	stack := make([]uintptr, 20)
	runtime.Callers(0, stack)

	go func() {
		timeoutTimer := l.getTimer(l.RTimeout)
		defer l.releaseTimer(timeoutTimer)
		select {
		case <-timeoutTimer.C:

			l.internalLock.Lock()
			if l.isLocked {
				l.rwMutex.Unlock()
			}
			l.internalLock.Unlock()

			l.rwMutex.RUnlock()
			l.handleTimeout(id, "Timeout obtaining or releasing read lock that came from: \n", stack)
		case <-doneChan:
			timeoutTimer.Stop()
			l.deleteChan(id)
		}
	}()

	l.rwMutex.RLock()
	return id
}

func (l *RWLock) RUnlock(id uint64) {
	l.sendDoneSig(id)
	l.rwMutex.RUnlock()
}
