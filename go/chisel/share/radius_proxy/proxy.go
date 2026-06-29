package radius_proxy

import (
	"crypto/hmac"
	"crypto/md5"
	"encoding/binary"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/chisel/share/cio"
	"layeh.com/radius"
	"layeh.com/radius/rfc2865"
	"layeh.com/radius/rfc2869"
)

const (
	packetFenceVendorID            = 29464
	packetFenceConnectorIDAttrType = 40
)

type Proxy struct {
	attributes_keys []string
	secret          []byte
	sessionTimeout  time.Duration
	authBackends    *Backends
	acctBackends    *Backends
	*cio.Logger
}

type ProxyConfig struct {
	AuthAddrs      []string
	AcctAddrs      []string
	Secret         []byte
	SessionTimeout time.Duration
	Logger         *cio.Logger
}

func NewProxy(config *ProxyConfig) *Proxy {
	radiusProxy := &Proxy{
		sessionTimeout: config.SessionTimeout,
		authBackends:   NewBackends(config.SessionTimeout, config.AuthAddrs...),
		acctBackends:   NewBackends(config.SessionTimeout, config.AcctAddrs...),
		secret:         []byte(config.Secret),
		Logger:         config.Logger,
	}

	return radiusProxy
}

// backendsForPacket selects the backend pool based on the RADIUS packet code.
// Accounting-Request packets are routed to the accounting pool (pfacct); every
// other packet (Access-Request, Status-Server, ...) goes to the authentication
// pool (radiusd-auth). Without this split an accounting packet could be hashed
// onto a radiusd-auth backend, which listens on the auth port and silently
// discards accounting.
func (rp *Proxy) backendsForPacket(p *radius.Packet) *Backends {
	if p.Code == radius.CodeAccountingRequest {
		return rp.acctBackends
	}

	return rp.authBackends
}

func (rp *Proxy) Cleanup(stop chan struct{}) {
	go rp.authBackends.sessions.Cleanup(5*time.Second, stop)
	go rp.acctBackends.sessions.Cleanup(5*time.Second, stop)
}

func (rp *Proxy) addProxyState(p *radius.Packet) bool {
	state := rfc2865.ProxyState_GetString(p)
	if state != "" {
		return false
	}

	backends := rp.backendsForPacket(p)
	id, _ := uuid.NewUUID()
	value := id.String()
	rfc2865.ProxyState_SetString(p, value)
	be := backends.pickBackend(p)
	backends.sessions.Add(value, rp.sessionTimeout, be)
	return true
}

func (rp *Proxy) AddAuthBackend(addr string) {
	rp.authBackends.Add(addr)
}

func (rp *Proxy) DeleteAuthBackend(addr string) {
	rp.authBackends.Delete(addr)
}

func (rp *Proxy) AddAcctBackend(addr string) {
	rp.acctBackends.Add(addr)
}

func (rp *Proxy) DeleteAcctBackend(addr string) {
	rp.acctBackends.Delete(addr)
}

func (rp *Proxy) ProxyPacket(payload []byte, connectorID string) ([]byte, string, error) {
	rp.Debugf("Finding backend to proxy to")
	packet, err := radius.Parse(payload, rp.secret)
	if err != nil {
		return nil, "", err
	}

	rp.IfDebugHandle(func(l *cio.Logger) {
		l.Printf("Payload to Proxy")
		LogPacket(l, packet)
	})

	added := rp.addProxyState(packet)
	_ = added

	if !hasPacketFenceConnectorID(packet) {
		connectorAttr, err := radius.NewString(connectorID)
		if err != nil {
			return nil, "", err
		}

		vendorConnectorAttr := make(radius.Attribute, 2+len(connectorAttr))
		vendorConnectorAttr[0] = packetFenceConnectorIDAttrType
		vendorConnectorAttr[1] = byte(len(vendorConnectorAttr))
		copy(vendorConnectorAttr[2:], connectorAttr)

		vsa, err := radius.NewVendorSpecific(packetFenceVendorID, vendorConnectorAttr)
		if err != nil {
			return nil, "", err
		}

		packet.Attributes.Add(26, vsa)
	}

	// All traffic reaching this proxy is connector traffic (the proxy is only
	// instantiated on the cloud side). The cloud FreeRADIUS validates it against
	// the `pfconnector` NAS client, whose shared secret is
	// unified_api_system_user.pass — the same secret rp.secret is wired to. Sign
	// the Message-Authenticator with it so validation succeeds end-to-end.
	err = addMessageAuthenticator(packet, rp.secret)
	if err != nil {
		return nil, "", err
	}

	b2, err := packet.Encode()
	if err != nil {
		return nil, "", err
	}

	be := rp.backendsForPacket(packet).getBackend(packet)
	if be == nil {
		return nil, "", errors.New("No backend available")
	}

	rp.Debugf("Proxy %s to %s for connector %s", packet.Code, be.addr, connectorID)
	rp.IfDebugHandle(func(l *cio.Logger) {
		l.Printf("Payload Proxied")
		LogPacket(l, packet)
	})
	return b2, be.addr, nil
}

func hasPacketFenceConnectorID(packet *radius.Packet) bool {
	for _, avp := range packet.Attributes {
		if avp.Type != 26 {
			continue
		}
		attr := avp.Attribute
		if len(attr) >= 5 &&
			binary.BigEndian.Uint32(attr[:4]) == packetFenceVendorID &&
			attr[4] == packetFenceConnectorIDAttrType {
			return true
		}
	}
	return false
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
