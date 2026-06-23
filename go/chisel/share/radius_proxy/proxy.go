package radius_proxy

import (
	"context"
	"crypto/hmac"
	"crypto/md5"
	"encoding/binary"
	"errors"
	"net"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/chisel/share/cio"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
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

	secret, err := rp.foundSecret(context.Background(), packet)

	if err != nil {
		secret = string(rp.secret)
	}

	err = addMessageAuthenticator(packet, []byte(secret))
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

func (rp *Proxy) foundSecret(ctx context.Context, packet *radius.Packet) (string, error) {

	var SwitchID []string
	SwitchMAC := rfc2865.CallingStationID_GetString(packet)
	if SwitchMAC != "" {
		MacHW, err := net.ParseMAC(SwitchMAC)
		if err == nil {
			SwitchMAC = MacHW.String()
			SwitchID = append(SwitchID, SwitchMAC)
		}
	}

	SwitchNasIP := rfc2865.NASIPAddress_Get(packet)
	if SwitchNasIP != nil {
		SwitchID = append(SwitchID, SwitchNasIP.String())
	}

	switches := pfconfigdriver.PfSwitches{}
	pfconfigdriver.FetchDecodeSocket(ctx, &switches)

	for _, switchID := range SwitchID {

		// Find the switch with the given ID
		for _, sw := range switches.PfconfigKeys.Keys {
			if sw != switchID {
				continue
			}
			switche := pfconfigdriver.PfConfSwitch{}
			switche.PfconfigHashNS = sw
			pfconfigdriver.FetchDecodeSocket(ctx, &switche)
			if switche.RadiusSecret.String() != "" {
				return switche.RadiusSecret.String(), nil
			}
		}
		// Find the switch within the ip ranges
		if IsIPv4(net.ParseIP(switchID)) {
			for _, sw := range switches.PfconfigKeys.Keys {
				_, network, err := net.ParseCIDR(sw)
				if err != nil {
					continue
				}
				if network.Contains(net.ParseIP(switchID)) {
					switche := pfconfigdriver.PfConfSwitch{}
					switche.PfconfigHashNS = sw
					pfconfigdriver.FetchDecodeSocket(ctx, &switche)
					if switche.RadiusSecret.String() != "" {
						return switche.RadiusSecret.String(), nil
					}
				}
			}
		}
	}
	return "", errors.New("No secret found")
}

func IsIPv4(address net.IP) bool {
	return strings.Count(address.String(), ":") < 2
}
