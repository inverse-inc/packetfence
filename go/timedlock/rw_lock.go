package timedlock

import (
	"fmt"
	"runtime"
	"sync"
	"time"
)

var timerPool = &sync.Pool{}

type RWLock struct {
	rwlockChan chan uint64
	rlockChan  chan uint64

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

	// Whether or not to enable output for debugging
	Debug bool
}

func NewRWLock() *RWLock {
	return &RWLock{
		rwlockChan:   make(chan uint64, 1),
		rlockChan:    make(chan uint64, 1024),
		Timeout:      10 * time.Second,
		RTimeout:     10 * time.Second,
		internalLock: &sync.Mutex{},
		Panic:        true,
		PrintErrors:  false,
	}
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

func (l *RWLock) getNextLockId() uint64 {
	l.internalLock.Lock()
	defer l.internalLock.Unlock()
	l.c++
	return l.c
}

func (l *RWLock) isLocked() bool {
	l.internalLock.Lock()
	defer l.internalLock.Unlock()
	return l.isLockedUnsafe()
}

func (l *RWLock) isLockedUnsafe() bool {
	return len(l.rwlockChan) > 0
}

func (l *RWLock) isRLocked() bool {
	l.internalLock.Lock()
	defer l.internalLock.Unlock()
	return l.isRLockedUnsafe()
}

func (l *RWLock) isRLockedUnsafe() bool {
	return len(l.rlockChan) > 0
}

func (l *RWLock) obtainExclusiveRLock(id uint64) bool {
	exChan := make(chan uint64, 1)
	go func() {
		start := time.Now()
		for {
			if !time.Now().Before(start.Add(l.Timeout)) {
				return
			}

			if !l.isRLockedUnsafe() {
				// We don't give a lot of time for this to happen
				// If the exChan isn't ready to receive, that means the timeout has hit
				timeoutTimer := l.getTimer(1 * time.Millisecond)
				defer l.releaseTimer(timeoutTimer)

				select {
				case exChan <- 1:
				case <-timeoutTimer.C:
				}
				return
			} else {
			}
		}
	}()

	timeoutTimer := l.getTimer(l.Timeout)
	defer l.releaseTimer(timeoutTimer)
	select {
	case <-timeoutTimer.C:
		if l.Debug {
			fmt.Println("Failed to obtain the exclusive RLock", id)
		}
		return false
	case <-exChan:
		timeoutTimer.Stop()
		return true
	}
}

func (l *RWLock) Lock() (uint64, bool) {
	id := l.getNextLockId()

	timeoutTimer := l.getTimer(l.Timeout)
	defer l.releaseTimer(timeoutTimer)

	l.internalLock.Lock()
	defer l.internalLock.Unlock()

	select {
	case <-timeoutTimer.C:
		l.handleTimeout(id, "Timeout obtaining or releasing lock that came from, failed while waiting to obtain the RW lock: \n")
		return id, false
	case l.rwlockChan <- id:
		timeoutTimer.Stop()
		if l.obtainExclusiveRLock(id) {
			if l.Debug {
				fmt.Println("Locked", id)
			}
			return id, true
		} else {
			defer func() {
				if l.Debug {
					fmt.Println("Released failed lock", id)
				}
				<-l.rwlockChan
			}()
			l.handleTimeout(id, "Timeout obtaining or releasing lock that came from, failed while waiting for the RLocks to clear: \n")
			return id, false
		}
	}
}

func (l *RWLock) Unlock(id uint64) {
	l.internalLock.Lock()
	defer l.internalLock.Unlock()
	if len(l.rwlockChan) != 1 {
		panic(fmt.Sprintf("Unlocking non-locked lock with ID %d", id))
	}
	chanId := <-l.rwlockChan
	if id != chanId {
		panic(fmt.Sprintf("Unmatched ID while unlocking. Expected %d and got %d", id, chanId))
	}
	if l.Debug {
		fmt.Println("Unlocked", id)
	}
}

func (l *RWLock) handleTimeout(id uint64, msg string) {
	stack := make([]uintptr, 20)
	runtime.Callers(0, stack)
	stackStr := ""
	frames := runtime.CallersFrames(stack)
	for {
		frame, more := frames.Next()
		if frame.Function == "" {
			break
		}
		stackStr += fmt.Sprintf("%d - %s\n\t%s:%d\n", id, frame.Function, frame.File, frame.Line)
		if !more {
			break
		}
	}

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

func (l *RWLock) RLock() (uint64, bool) {
	id := l.getNextLockId()

	l.internalLock.Lock()
	defer l.internalLock.Unlock()

	exChan := make(chan uint64, 1)
	go func() {
		start := time.Now()
		for {
			if !time.Now().Before(start.Add(l.RTimeout)) {
				return
			}
			if !l.isLockedUnsafe() {
				// We don't give a lot of time for this to happen
				// If the exChan isn't ready to receive, that means the timeout has hit
				timeoutTimer := l.getTimer(1 * time.Millisecond)
				defer l.releaseTimer(timeoutTimer)

				select {
				case exChan <- 1:
				case <-timeoutTimer.C:
				}
				return
			}
		}
	}()

	timeoutTimer := l.getTimer(l.RTimeout)
	defer l.releaseTimer(timeoutTimer)
	select {
	case <-timeoutTimer.C:
		l.handleTimeout(id, "Timeout obtaining or releasing lock that came from: \n")
		return id, false
	case <-exChan:
		timeoutTimer.Stop()
		l.rlockChan <- id
		return id, true
	}

}

func (l *RWLock) RUnlock(id uint64) {
	<-l.rlockChan
}
