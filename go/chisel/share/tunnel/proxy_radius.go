package tunnel

import (
	"context"
	"crypto/hmac"
	"crypto/md5"
	"hash/fnv"
	"net"
	"sync"
	"time"

	"github.com/google/uuid"
	"layeh.com/radius"
	"layeh.com/radius/rfc2865"
	"layeh.com/radius/rfc2869"
)

type RadiusBackend struct {
	addr     string
	client   radius.Client
	sLock    sync.RWMutex
	sessions map[string]struct{}
}

func (be *RadiusBackend) addSession(s string) {
	be.sLock.Lock()
	defer be.sLock.Unlock()
	be.sessions[s] = struct{}{}
}

type stateBackend struct {
	lock   *sync.RWMutex
	states map[string]*RadiusBackend
}

func (sb *stateBackend) Remove(k string) {
	sb.lock.Lock()
	delete(sb.states, k)
	defer sb.lock.Unlock()
}

func (sb *stateBackend) Add(k string, be *RadiusBackend) {
	sb.lock.Lock()
	defer sb.lock.Unlock()
	sb.states[k] = be
}

func newStateBackend() stateBackend {
	return stateBackend{
		lock:   &sync.RWMutex{},
		states: map[string]*RadiusBackend{},
	}
}

func (be *RadiusBackend) Cleanup(b *RadiusBackends) {
	for s, _ := range be.sessions {
		b.states.Remove(s)
	}
}

type RadiusBackends struct {
	lock     *sync.RWMutex
	keys     []string
	backends map[string]*RadiusBackend
	states   stateBackend
}

func (sb *stateBackend) getBackend(packet *radius.Packet) *RadiusBackend {
	state := rfc2865.ProxyState_GetString(packet)
	if state == "" {
		return nil
	}

	sb.lock.RLock()
	defer sb.lock.RUnlock()
	if be, found := sb.states[state]; found {
		return be
	}

	return nil
}

func (b *RadiusBackends) getBackend(p *radius.Packet) *RadiusBackend {
	be := b.states.getBackend(p)
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

	b.backends[addr] = NewRadiusBackend(addr, b)
	b.keys = append(b.keys, addr)
}

func (b *RadiusBackends) Delete(addr string) {
	b.lock.Lock()
	defer b.lock.Unlock()
	be, found := b.backends[addr]
	if !found {
		return
	}

	for i, k := range b.keys {
		if k != addr {
			continue
		}

		b.keys = append(b.keys[:i], b.keys[i+1:]...)
		delete(b.backends, addr)
		go func() {
			time.Sleep(20 * time.Second)
			be.Cleanup(b)
		}()

		break
	}
}

type RadiusProxy struct {
	attributes_keys []string
	secret          string
	backends        *RadiusBackends
}

func (rp *RadiusProxy) addProxyState(p *radius.Packet) bool {
	state := rfc2865.ProxyState_GetString(p)
	if state != "" {
		return false
	}

	id, _ := uuid.NewUUID()
	value := id.String()
	rfc2865.ProxyState_SetString(p, value)
	be := rp.backends.pickBackend(p)
	be.addSession(value)
	rp.backends.states.Add(value, be)
	return true
}

func (rp *RadiusProxy) ProxyPacket(h *udpHandler, p *udpPacket) ([]byte, string, error) {
	packet, err := radius.Parse(p.Payload, []byte(rp.secret))
	if err != nil {
		return nil, "", err
	}

	added := rp.addProxyState(packet)
	_ = added
	connectorAttr, err := radius.NewString(h.connectorID)
	if err != nil {
		return nil, "", err
	}

	vendorConnectorAttr := make(radius.Attribute, 2+len(connectorAttr))
	vendorConnectorAttr[0] = 40
	vendorConnectorAttr[1] = byte(len(vendorConnectorAttr))
	copy(vendorConnectorAttr[2:], connectorAttr)

	vsa, err := radius.NewVendorSpecific(29464, vendorConnectorAttr)
	if err != nil {
		return nil, "", err
	}

	packet.Attributes.Add(26, vsa)
	err = addMessageAuthenticator(packet, []byte(rp.secret))
	if err != nil {
		return nil, "", err
	}

	b2, err := packet.Encode()
	if err != nil {
		return nil, "", err
	}

	be := rp.backends.getBackend(packet)
	return b2, be.addr, nil
}

func addMessageAuthenticator(p *radius.Packet, secret []byte) error {
	rfc2869.MessageAuthenticator_Del(p)
	hash := hmac.New(md5.New, secret)
	rfc2869.MessageAuthenticator_Set(p, []byte{0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0})
	encode, err := p.Encode()
	if err != nil {
		return err
	}

	hash.Write(encode)
	rfc2869.MessageAuthenticator_Set(p, hash.Sum(nil))
	return nil
}

type BackendRequest struct {
	writer  radius.ResponseWriter
	request *radius.Request
}

func (p *RadiusProxy) RADIUSSecret(ctx context.Context, remoteAddr net.Addr, raw []byte) ([]byte, context.Context, error) {
	return []byte(p.secret), ctx, nil
}

func NewRadiusBackends(addrs ...string) *RadiusBackends {
	b := &RadiusBackends{
		lock:     &sync.RWMutex{},
		backends: map[string]*RadiusBackend{},
		states:   newStateBackend(),
	}

	for _, a := range addrs {
		b.add(a)
	}

	return b
}

func NewRadiusBackend(addr string, b *RadiusBackends) *RadiusBackend {
	be := &RadiusBackend{
		addr: addr,
		client: radius.Client{
			Net:             "udp",
			Retry:           time.Second,
			MaxPacketErrors: 0,
		},
		sLock:    sync.RWMutex{},
		sessions: map[string]struct{}{},
	}

	return be
}
