package radius_proxy

import (
	"hash/fnv"
	"sync"
	"time"

	"layeh.com/radius"
	"layeh.com/radius/rfc2865"
)

type RadiusBackends struct {
	lock           *sync.RWMutex
	keys           []string
	backends       map[string]*RadiusBackend
	sessions       *RadiusSessionBackend
	sessionTimeout time.Duration
}

func NewRadiusBackends(timeout time.Duration, addrs ...string) *RadiusBackends {
	b := &RadiusBackends{
		lock:           &sync.RWMutex{},
		backends:       map[string]*RadiusBackend{},
		sessions:       NewRadiusSessionBackend(),
		sessionTimeout: timeout,
	}

	for _, a := range addrs {
		b.add(a)
	}

	return b
}

func (b *RadiusBackends) getBackend(p *radius.Packet) *RadiusBackend {
	be := b.sessions.GetBackend(p)
	if be != nil {
		return be
	}

	return b.pickBackend(p)
}

func (b *RadiusBackends) pickBackend(p *radius.Packet) *RadiusBackend {
	b.lock.RLock()
	defer b.lock.RUnlock()
	i := b.loadBalanceIndex(p)
	return b.backends[b.keys[i]]
}

func (b *RadiusBackends) loadBalanceIndex(packet *radius.Packet) int {
	hash := fnv.New32()
	username := rfc2865.UserName_Get(packet)
	callingStation := rfc2865.CallingStationID_Get(packet)
	hash.Write(username)
	hash.Write([]byte{','})
	hash.Write(callingStation)
	return int(hash.Sum32()) % len(b.keys)
}

func (b *RadiusBackends) Add(addr string) {
	b.lock.Lock()
	defer b.lock.Unlock()
	b.add(addr)
}

func (b *RadiusBackends) add(addr string) {
	if _, found := b.backends[addr]; found {
		return
	}

	b.backends[addr] = NewRadiusBackend(addr)
	b.keys = append(b.keys, addr)
}

func (b *RadiusBackends) Delete(addr string) {
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
