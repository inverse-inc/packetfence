package timedlock

import (
	"fmt"
	"math"
	"sync"
	"testing"
	"time"
)

func TestRWLockLock(t *testing.T) {
	{
		l := NewRWLock()
		l.Timeout = 100 * time.Millisecond

		id, success := l.Lock()

		if !success {
			t.Error("Failed to lock")
		}

		l.Unlock(id)

		// Sleep for twice the timeout to make sure this will not panic
		time.Sleep(200 * time.Millisecond)
	}

	{
		l := NewRWLock()
		l.Timeout = 100 * time.Millisecond
		l.Panic = false
		l.LockFailures = make(chan uint64, 10)

		id0, _ := l.Lock()
		id1, _ := l.Lock()

		// Sleep for twice the timeout
		time.Sleep(200 * time.Millisecond)

		select {
		case failId := <-l.LockFailures:
			if id1 != failId {
				t.Error("ID from the LockFailures channel doesn't match")
			}
		case <-time.After(1 * time.Second):
			t.Error("Couldn't detect failure via the LockFailures chan")
		}

		l.Unlock(id0)

		// Should now be able to lock again
		id2, success := l.Lock()

		if !success {
			t.Error("Failed to lock")
		}

		l.Unlock(id2)

		select {
		case <-l.LockFailures:
			t.Error("There was a lock failure but there shouldn't have been one")
		case <-time.After(1 * time.Second):
			// All good
		}
	}

}

func TestRWLockRLock(t *testing.T) {
	{
		l := NewRWLock()
		l.RTimeout = 100 * time.Millisecond

		id, success := l.RLock()

		if !success {
			t.Error("Failed to RLock")
		}

		l.RUnlock(id)

		// Sleep for twice the timeout
		time.Sleep(200 * time.Millisecond)

	}

	{
		l := NewRWLock()
		l.RTimeout = 100 * time.Millisecond

		id1, success := l.RLock()
		if !success {
			t.Error("Failed to RLock")
		}

		id2, success := l.RLock()
		if !success {
			t.Error("Failed to RLock")
		}

		l.RUnlock(id1)
		l.RUnlock(id2)

		// Sleep for twice the timeout
		time.Sleep(200 * time.Millisecond)
	}

	{
		l := NewRWLock()
		l.RTimeout = 100 * time.Millisecond
		l.Panic = false
		l.LockFailures = make(chan uint64, 1)

		id1, success := l.RLock()
		if !success {
			t.Error("Failed to obtain RLock")
		}
		id2, success := l.RLock()
		if !success {
			t.Error("Failed to obtain RLock")
		}
		fmt.Println(id2)

		l.RUnlock(id1)

		// Sleep for twice the timeout
		time.Sleep(200 * time.Millisecond)
	}
}

func TestRWLockMaxRestart(t *testing.T) {
	l := NewRWLock()

	l.c = math.MaxUint64 - 1

	id, _ := l.Lock()
	if id != math.MaxUint64 {
		t.Error("Wrong ID came out of the lock")
	}
	l.Unlock(id)

	id, _ = l.Lock()
	// Should now go back to the beginning
	if id != 0 {
		t.Error("Wrong ID came out of the lock")
	}
	l.Unlock(id)
}

func TestRWLockOverflow(t *testing.T) {
	l := NewRWLock()

	func() {
		defer func() {
			if r := recover(); r == nil {
				t.Error("Didn't recover an error when a non deleted channel ID was reused")
			}
		}()

		id, _ := l.Lock()
		l.c = id - 1
		l.Lock()
	}()
}

func BenchmarkSyncRWMutex(b *testing.B) {
	m := sync.RWMutex{}
	for i := 0; i < b.N; i++ {
		m.Lock()
		m.Unlock()
	}

	for i := 0; i < b.N; i++ {
		m.RLock()
		m.RUnlock()
	}
}

func BenchmarkRWLock(b *testing.B) {
	m := NewRWLock()
	for i := 0; i < b.N; i++ {
		id, _ := m.Lock()
		m.Unlock(id)
	}

	for i := 0; i < b.N; i++ {
		id, _ := m.RLock()
		m.RUnlock(id)
	}
}
