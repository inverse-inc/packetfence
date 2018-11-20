package timedlock

import (
	"errors"
	"fmt"
	"runtime"
	"sync"
	"time"
)

var timerPool = &sync.Pool{}

const MAX_RLOCK = 1000

var TIMEOUT_ERROR = errors.New("Timeout occured")

type RWLock struct {
	internalLock *sync.Mutex

	lockChan  chan int
	rlockChan chan int

	// A counter to track the amount of allocated locks for providing the next ID
	c uint64

	// The timeout for Lock operations
	Timeout time.Duration

	// The timeout for RLock operations
	RTimeout time.Duration

	// Whether or not this should panic on timeouts
	// Otherwise, it will just release the lock
	Panic bool

	// Whether or not the errors should be printed
	PrintErrors bool
}

func NewRWLock() *RWLock {
	l := &RWLock{
		lockChan:     make(chan int, 1),
		rlockChan:    make(chan int, MAX_RLOCK),
		Timeout:      10 * time.Second,
		RTimeout:     10 * time.Second,
		internalLock: &sync.Mutex{},
		Panic:        true,
		PrintErrors:  false,
		c:            1,
	}
	l.lockChan <- 1
	for i := 0; i < MAX_RLOCK; i++ {
		l.rlockChan <- 1
	}
	return l
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

func (l *RWLock) getNextId() uint64 {
	l.internalLock.Lock()
	defer l.internalLock.Unlock()
	l.c++
	// 0 isn't an acceptable ID
	if l.c == 0 {
		l.c++
	}
	return l.c
}

func (l *RWLock) Lock() (uint64, error) {
	id := l.getNextId()
	stopAt := time.Now().Add(l.Timeout)
	timeoutTimer := l.getTimer(l.Timeout)
	defer l.releaseTimer(timeoutTimer)

	select {
	case <-timeoutTimer.C:
		l.handleTimeout(id, "Timeout obtaining or releasing lock that came from: \n")
		return 0, TIMEOUT_ERROR
	case <-l.lockChan:
		timeoutTimer.Stop()
		for time.Now().Before(stopAt) {
			l.internalLock.Lock()
			if len(l.rlockChan) == MAX_RLOCK {
				l.internalLock.Unlock()
				return id, nil
			} else {
				l.internalLock.Unlock()
				time.Sleep(1 * time.Millisecond)
			}
		}

		l.lockChan <- 1
		l.handleTimeout(id, "Timeout obtaining or releasing lock that came from: \n")
	}
	return 0, TIMEOUT_ERROR
}

func (l *RWLock) Unlock(id uint64) {
	l.internalLock.Lock()
	defer l.internalLock.Unlock()
	if len(l.lockChan) != 0 {
		panic("Unlock of unlocked mutex")
	} else if id == 0 {
		panic("Unlocking mutex with ID 0")
	} else {
		l.lockChan <- 1
	}
}

func (l *RWLock) getStack() string {
	stack := make([]uintptr, 20)
	runtime.Callers(2, stack)

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

	return stackStr
}

func (l *RWLock) handleTimeout(id uint64, msg string) {
	stackStr := l.getStack()

	msg = fmt.Sprintf("%d %s %s", id, msg, stackStr)
	if l.Panic {
		panic(msg)
	} else if l.PrintErrors {
		fmt.Println(msg)
	}
}

func (l *RWLock) RLock() (uint64, error) {
	id := l.getNextId()
	timeoutTimer := l.getTimer(l.RTimeout)
	defer l.releaseTimer(timeoutTimer)

	select {
	case <-timeoutTimer.C:
		l.handleTimeout(id, "Timeout obtaining or releasing read lock that came from: \n")
		return 0, TIMEOUT_ERROR
	case <-l.lockChan:
		l.internalLock.Lock()
		select {
		case <-timeoutTimer.C:
			l.lockChan <- 1
			l.internalLock.Unlock()
			l.handleTimeout(id, "Timeout obtaining or releasing read lock that came from: \n")
			return 0, TIMEOUT_ERROR
		case <-l.rlockChan:
			l.lockChan <- 1
			l.internalLock.Unlock()
			return id, nil
		}
	}
}

func (l *RWLock) RUnlock(id uint64) {
	l.internalLock.Lock()
	defer l.internalLock.Unlock()
	if len(l.rlockChan) >= MAX_RLOCK {
		panic("RUnlock of unlocked mutex")
	} else if id == 0 {
		panic("Unlocking mutex with ID 0")
	} else {
		l.rlockChan <- 1
	}
}
