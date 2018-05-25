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

		id := l.Lock()

		if l.doneChans[id] == nil {
			t.Error("Locking didn't create a done channel")
		}

		l.Unlock(id)

		// Sleep for twice the timeout to make sure this will not panic
		time.Sleep(200 * time.Millisecond)

		if l.doneChans[id] != nil {
			t.Error("Channel is still there even after unlocking")
		}
	}

	{
		l := NewRWLock()
		l.Timeout = 100 * time.Millisecond
		l.Panic = false
		l.LockFailures = make(chan uint64)

		id := l.Lock()

		if l.doneChans[id] == nil {
			t.Error("Locking didn't create a done channel")
		}

		// Sleep for twice the timeout
		time.Sleep(200 * time.Millisecond)

		select {
		case failId := <-l.LockFailures:
			if id != failId {
				t.Error("ID from the LockFailures channel doesn't match")
			}
		case <-time.After(1 * time.Second):
			t.Error("Couldn't detect failure via the LockFailures chan")
		}

		if l.doneChans[id] != nil {
			t.Error("Channel is still there even after unlocking via a timeout")
		}

		// Should now be able to lock again
		id2 := l.Lock()
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

		id := l.RLock()

		if l.doneChans[id] == nil {
			t.Error("Locking didn't create a done channel")
		}

		l.RUnlock(id)

		// Sleep for twice the timeout
		time.Sleep(200 * time.Millisecond)

		if l.doneChans[id] != nil {
			t.Error("Channel is still there even after unlocking")
		}
	}

	{
		l := NewRWLock()
		l.RTimeout = 100 * time.Millisecond

		id1 := l.RLock()
		id2 := l.RLock()

		if l.doneChans[id1] == nil {
			t.Error("Locking didn't create a done channel")
		}
		if l.doneChans[id2] == nil {
			t.Error("Locking didn't create a done channel")
		}

		l.RUnlock(id1)
		l.RUnlock(id2)

		// Sleep for twice the timeout
		time.Sleep(200 * time.Millisecond)

		if l.doneChans[id1] != nil {
			t.Error("Channel is still there even after unlocking")
		}

		if l.doneChans[id2] != nil {
			t.Error("Channel is still there even after unlocking")
		}
	}

	{
		l := NewRWLock()
		l.RTimeout = 100 * time.Millisecond
		l.Panic = false
		l.LockFailures = make(chan uint64)

		id1 := l.RLock()
		id2 := l.RLock()
		fmt.Println(id2)

		if l.doneChans[id1] == nil {
			t.Error("Locking didn't create a done channel")
		}
		if l.doneChans[id2] == nil {
			t.Error("Locking didn't create a done channel")
		}

		l.RUnlock(id1)

		// Sleep for twice the timeout
		time.Sleep(200 * time.Millisecond)

		if l.doneChans[id1] != nil {
			t.Error("Channel is still there even after unlocking")
		}

		select {
		case failId := <-l.LockFailures:
			if id2 != failId {
				t.Error("ID from the LockFailures channel doesn't match")
			}
		case <-time.After(1 * time.Second):
			t.Error("Couldn't detect failure via the LockFailures chan")
		}

		if l.doneChans[id2] != nil {
			t.Error("Channel is still there even after timeout unlocking")
		}

	}
}

func TestRWLockMaxRestart(t *testing.T) {
	l := NewRWLock()

	l.c = math.MaxUint64 - 1

	id := l.Lock()
	if id != math.MaxUint64 {
		t.Error("Wrong ID came out of the lock")
	}
	l.Unlock(id)

	id = l.Lock()
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

		id := l.Lock()
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
		id := m.Lock()
		m.Unlock(id)
	}

	for i := 0; i < b.N; i++ {
		id := m.RLock()
		m.RUnlock(id)
	}
}
