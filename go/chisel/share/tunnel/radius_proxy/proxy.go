package radius_proxy

import (
	"crypto/hmac"
	"crypto/md5"
	"time"

	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/chisel/share/cio"
	"layeh.com/radius"
	"layeh.com/radius/rfc2865"
	"layeh.com/radius/rfc2869"
)

type Proxy struct {
	attributes_keys []string
	secret          []byte
	sessionTimeout  time.Duration
	backends        *Backends
	*cio.Logger
}

type ProxyConfig struct {
	Addrs          []string
	Secret         []byte
	SessionTimeout time.Duration
	Logger         *cio.Logger
}

func NewProxy(config *ProxyConfig) *Proxy {
	radiusProxy := &Proxy{
		sessionTimeout: config.SessionTimeout,
		backends:       NewBackends(config.SessionTimeout, config.Addrs...),
		secret:         []byte(config.Secret),
		Logger:         config.Logger,
	}

	return radiusProxy
}

func (rp *Proxy) Cleanup(stop chan struct{}) {
	rp.backends.sessions.Cleanup(5*time.Second, stop)
}

func (rp *Proxy) addProxyState(p *radius.Packet) bool {
	state := rfc2865.ProxyState_GetString(p)
	if state != "" {
		return false
	}

	id, _ := uuid.NewUUID()
	value := id.String()
	rfc2865.ProxyState_SetString(p, value)
	be := rp.backends.pickBackend(p)
	rp.backends.sessions.Add(value, rp.sessionTimeout, be)
	return true
}

func (rp *Proxy) AddBackend(addr string) {
	rp.backends.Add(addr)
}

func (rp *Proxy) DeleteBackend(addr string) {
	rp.backends.Delete(addr)
}

func (rp *Proxy) ProxyPacket(payload []byte, connectorID string) ([]byte, string, error) {
	packet, err := radius.Parse(payload, rp.secret)
	if err != nil {
		return nil, "", err
	}

	added := rp.addProxyState(packet)
	_ = added
	connectorAttr, err := radius.NewString(connectorID)
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
	rp.Debugf("Proxy to %s for connector %s", be.addr, connectorID)
	return b2, be.addr, nil
}

func addMessageAuthenticator(p *radius.Packet, secret []byte) error {
	rfc2869.MessageAuthenticator_Del(p)
	hash := hmac.New(md5.New, secret)
	rfc2869.MessageAuthenticator_Set(p, []byte{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0})
	encode, err := p.Encode()
	if err != nil {
		return err
	}

	hash.Write(encode)
	rfc2869.MessageAuthenticator_Set(p, hash.Sum(nil))
	return nil
}
