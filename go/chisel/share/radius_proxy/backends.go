package radius_proxy

import (
	"hash/fnv"
	"sync"
	"time"

	"layeh.com/radius"
	"layeh.com/radius/rfc2865"
)

type Backend struct {
	addr string
}

func NewBackend(addr string) *Backend {
	be := &Backend{
		addr: addr,
	}

	return be
}

type Backends struct {
	lock           *sync.RWMutex
	keys           []string
	backends       map[string]*Backend
	sessions       *SessionBackend
	sessionTimeout time.Duration
}

func NewBackends(timeout time.Duration, addrs ...string) *Backends {
	b := &Backends{
		lock:           &sync.RWMutex{},
		backends:       map[string]*Backend{},
		sessions:       NewSessionBackend(),
		sessionTimeout: timeout,
	}

	for _, a := range addrs {
		b.add(a)
	}

	return b
}

func (b *Backends) getBackend(p *radius.Packet) *Backend {
	be := b.sessions.GetBackend(p)
	if be != nil {
		return be
	}

	return b.pickBackend(p)
}

func (b *Backends) pickBackend(p *radius.Packet) *Backend {
	b.lock.RLock()
	defer b.lock.RUnlock()
	if len(b.backends) == 0 {
		return nil
	}

	i := b.loadBalanceIndex(p)
	return b.backends[b.keys[i]]
}

func (b *Backends) loadBalanceIndex(packet *radius.Packet) int {
	hash := fnv.New32()
	username := rfc2865.UserName_Get(packet)
	callingStation := rfc2865.CallingStationID_Get(packet)
	hash.Write(username)
	hash.Write([]byte{','})
	hash.Write(callingStation)
	return int(hash.Sum32()) % len(b.keys)
}

func (b *Backends) Add(addr string) {
	b.lock.Lock()
	defer b.lock.Unlock()
	b.add(addr)
}

func (b *Backends) add(addr string) {
	if _, found := b.backends[addr]; found {
		return
	}

	b.backends[addr] = NewBackend(addr)
	b.keys = append(b.keys, addr)
}

func (b *Backends) Delete(addr string) {
	b.lock.Lock()
	defer b.lock.Unlock()
	_, found := b.backends[addr]
	if !found {
		return
	}

	for i, k := range b.keys {
		if k != addr {
			continue
		}

		b.keys = append(b.keys[:i], b.keys[i+1:]...)
		delete(b.backends, addr)
		break
	}
}
