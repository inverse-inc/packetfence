package timedlock

import (
	"math"
	"sync"
	"testing"
	"time"
)

func TestRWLockLock(t *testing.T) {
	{
		l := NewRWLock()
		l.Timeout = 100 * time.Millisecond

		id, _ := l.Lock()

		if id == 0 {
			t.Error("Error while locking, got zero ID")
		}

		if len(l.lockChan) != 0 {
			t.Error("Locking didn't remove the value from the lock channel")
		}

		l.Unlock(id)
	}

	{
		l := NewRWLock()
		l.Timeout = 100 * time.Millisecond
		l.Panic = false

		id1, _ := l.Lock()

		if id1 == 0 {
			t.Error("Error while locking, got zero ID")
		}

		if len(l.lockChan) != 0 {
			t.Error("Locking didn't remove the value from the lock channel")
		}

		// Can't lock twice
		id2, _ := l.Lock()

		if id2 != 0 {
			t.Error("Got non-zero ID when attempting to lock locked mutex for longer than the timeout")
		}

		if len(l.lockChan) != 0 {
			t.Error("Failed locking has altered the lockChan")
		}

		l.Unlock(id1)

		if len(l.lockChan) != 1 {
			t.Error("Unlocking didn't make the lockChan available again")
		}

		// Should now be able to lock again

		id3, _ := l.Lock()

		if id3 == 0 {
			t.Error("Error while locking, got zero ID")
		}

		if len(l.lockChan) != 0 {
			t.Error("Locking didn't remove the value from the lock channel")
		}

	}
	// Can't lock if its rlocked
	{
		l := NewRWLock()
		l.RTimeout = 100 * time.Millisecond
		l.Panic = false

		id1, _ := l.RLock()
		id2, _ := l.Lock()

		if id1 == 0 || id2 != 0 {
			t.Error("Wrong ID came out of the lock")
		}

		if len(l.lockChan) != 1 {
			t.Error("lockChan was decremented")
		}

		// TODO: magic number
		if len(l.rlockChan) != 999 {
			t.Error("rlockChan wasn't decremented", len(l.rlockChan))
		}

		// Will be able to lock when its unlocked
		l.RUnlock(id1)

		id3, _ := l.Lock()

		if id3 == 0 {
			t.Error("Wrong ID came out of the lock")
		}
	}
}

func TestRWLockRLock(t *testing.T) {
	{
		l := NewRWLock()
		l.RTimeout = 100 * time.Millisecond

		id, _ := l.RLock()

		if id == 0 {
			t.Error("Wrong ID came out of the lock")
		}

		// TODO: magic number
		if len(l.rlockChan) != 999 {
			t.Error("rlockChan wasn't decremented")
		}

		l.RUnlock(id)

		// TODO: magic number
		if len(l.rlockChan) != 1000 {
			t.Error("rlockChan wasn't decremented")
		}

	}

	{
		l := NewRWLock()
		l.RTimeout = 100 * time.Millisecond
		l.Panic = false

		id1, _ := l.RLock()
		id2, _ := l.RLock()

		if id1 == 0 || id2 == 0 {
			t.Error("Wrong ID came out of the lock")
		}

		// TODO: magic number
		if len(l.rlockChan) != 998 {
			t.Error("rlockChan wasn't decremented")
		}
	}

	// Can't rlock if its locked
	{
		l := NewRWLock()
		l.RTimeout = 100 * time.Millisecond
		l.Panic = false

		id1, _ := l.Lock()
		id2, _ := l.RLock()

		if id1 == 0 || id2 != 0 {
			t.Error("Wrong ID came out of the lock")
		}

		if len(l.lockChan) != 0 {
			t.Error("lockChan wasn't decremented")
		}

		// TODO: magic number
		if len(l.rlockChan) != 1000 {
			t.Error("rlockChan was decremented", len(l.rlockChan))
		}

		// Will be able to lock when its unlocked
		l.Unlock(id1)

		id3, _ := l.RLock()

		if id3 == 0 {
			t.Error("Wrong ID came out of the lock")
		}
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
	// Should now go back to the beginning but not at zero
	if id != 1 {
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
