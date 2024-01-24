package radius_proxy

import (
	"errors"
	"sync"
	"time"

	"layeh.com/radius"
	"layeh.com/radius/rfc2865"
)

type SessionBackend struct {
	store sync.Map
}

func NewSessionBackend() *SessionBackend {
	return &SessionBackend{
		store: sync.Map{},
	}
}

func NewRadiusSession(id string, timeout time.Duration, backend *Backend) *RadiusSession {
	return &RadiusSession{
		backend: backend,
		id:      id,
		endTime: time.Now().Add(timeout),
		timeout: timeout,
		lock:    &sync.RWMutex{},
	}
}

func (sb *SessionBackend) Cleanup(tick time.Duration, stop chan struct{}) {
	ticker := time.NewTicker(tick)
loop:
	for {
		select {
		case <-ticker.C:
			sb.cleanup()
		case <-stop:
			ticker.Stop()
			break loop
		}
	}
}

func (sb *SessionBackend) GetBackend(packet *radius.Packet) *Backend {
	state := rfc2865.ProxyState_GetString(packet)
	if state == "" {
		return nil
	}

	if val, ok := sb.store.Load(state); ok {
		rs := val.(*RadiusSession)
		if rs.ExtendTime() == nil {
			return rs.backend
		}
	}

	return nil
}

func (sb *SessionBackend) cleanup() {
	sb.store.Range(
		func(key, value any) bool {
			rs := value.(*RadiusSession)
			rs.lock.Lock()
			defer rs.lock.Unlock()
			if rs.expired() != nil {
				sb.store.Delete(key)
			}

			return true
		},
	)
}

func (rs *SessionBackend) Add(id string, timeout time.Duration, backend *Backend) {
	rs.store.Store(
		id,
		NewRadiusSession(
			id,
			timeout,
			backend,
		),
	)
}

type RadiusSession struct {
	id      string
	timeout time.Duration
	endTime time.Time
	backend *Backend
	lock    *sync.RWMutex
}

var SessionTimeoutErr = errors.New("Session Timed out")

func (rs *RadiusSession) Expired() error {
	rs.lock.RLock()
	defer rs.lock.RUnlock()
	return rs.expired()
}

func (rs *RadiusSession) expired() error {
	if rs.endTime.Before(time.Now()) {
		return SessionTimeoutErr
	}

	return nil
}

func (rs *RadiusSession) ExtendTime() error {
	rs.lock.Lock()
	defer rs.lock.Unlock()
	if err := rs.expired(); err != nil {
		return err
	}

	rs.endTime = time.Now().Add(rs.timeout)
	return nil
}
