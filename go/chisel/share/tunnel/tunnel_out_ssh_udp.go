package tunnel

import (
	"encoding/gob"
	"fmt"
	"io"
	"net"
	"os"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/chisel/share/cio"
	"github.com/inverse-inc/packetfence/go/chisel/share/radius_proxy"
	"github.com/inverse-inc/packetfence/go/chisel/share/settings"
)

var udpCloseOnReply = sharedutils.IsEnabled(sharedutils.EnvOrDefault("PFCONNECTOR_UDP_CLOSE_ON_REPLY", "disabled"))

func (t *Tunnel) handleUDP(l *cio.Logger, rwc io.ReadWriteCloser, hostPort string, handler string) error {
	conns := &udpConns{
		Logger: l,
		m:      map[string]*udpConn{},
		srcIP:  t.Config.SrcIP,
	}
	defer conns.closeAll()
	h := &udpHandler{
		connectorID: t.ConnectorID,
		Logger:      l,
		hostPort:    hostPort,
		handler:     handler,
		udpChannel: &udpChannel{
			r: gob.NewDecoder(rwc),
			w: gob.NewEncoder(rwc),
			c: rwc,
		},
		radiusProxy: t.radiusProxy,
		udpConns:    conns,
	}
	for {
		p := udpPacket{}
		if err := h.handleWrite(&p); err != nil {
			return err
		}
	}
}

type udpHandler struct {
	connectorID string
	*cio.Logger
	hostPort    string
	radiusProxy *radius_proxy.Proxy
	*udpChannel
	*udpConns
	handler string
}

func (h *udpHandler) isRadius(p *udpPacket) bool {
	return h.radiusProxy != nil
}

func (h *udpHandler) handleWrite(p *udpPacket) error {
	var err error
	if err = h.r.Decode(&p); err != nil {
		return err
	}

	packet, hostPort := p.Payload, h.hostPort
	switch h.handler {
	default:
		h.Debugf("Proxying raw UDP")
	case "radius":
		if h.radiusProxy != nil {
			h.Debugf("Proxying RADIUS")
			packet, hostPort, err = h.radiusProxy.ProxyPacket(packet, h.connectorID)
			if err != nil {
				return err
			}
		} else {
			h.Infof("Radius Proxy not config properly")
			h.Debugf("Proxying raw UDP")
		}
	}
	//dial now, we know we must write
	conn, exists, err := h.udpConns.dial(p.Src, hostPort)
	if err != nil {
		return err
	}

	h.Debugf("Writing host port: '%s', UDP conn: '%s'", hostPort, conn.id)
	//however, we dont know if we must read...
	//spawn up to <max-conns> go-routines to wait
	//for a reply.
	//TODO configurable
	//TODO++ dont use go-routines, switch to pollable
	//  array of listeners where all listeners are
	//  sweeped periodically, removing the idle ones
	maxConns := sharedutils.EnvOrDefaultInt("PFCONNECTOR_UDP_MAX_CONNS", 1000)
	if !exists {
		if h.udpConns.len() <= maxConns {
			go h.handleRead(p, conn)
		} else {
			h.Infof("exceeded max udp connections (%d)", maxConns)
		}
	}
	// TODO: Only apply this to remotes that are specific to RADIUS
	_, err = conn.Write(packet)
	if err != nil {
		return err
	}

	return nil
}

func (h *udpHandler) handleRead(p *udpPacket, conn *udpConn) {
	//ensure connection is cleaned up
	defer h.udpConns.remove(conn.id)
	const maxMTU = 9012
	buff := make([]byte, maxMTU)
	//response must arrive within 5 seconds
	deadline := settings.EnvDuration("UDP_DEADLINE", 5*time.Second)
	h.Debugf("Reading host port: '%s', UDP conn: '%s'", h.hostPort, conn.id)
	for {
		conn.SetReadDeadline(time.Now().Add(deadline))
		//read response
		n, err := conn.Read(buff)
		if err != nil {
			if !os.IsTimeout(err) && err != io.EOF {
				h.Debugf("read error %s: %s", conn, err)
			} else {
				h.Debugf("closing connection %s", conn)
			}
			break
		}
		b := buff[:n]
		//encode back over ssh connection
		err = h.udpChannel.encode(p.Src, b)
		if err != nil {
			h.Debugf("encode error %s: %s", conn, err)
			return
		}
		// Enabling this makes it so less active connections are kept at the cost of re-dialing if there is a continious exchange in that specific UDP connection
		if udpCloseOnReply {
			h.Debugf("UDP close on reply %s", conn)
		}
	}
}

type udpConns struct {
	*cio.Logger
	sync.Mutex
	srcIP net.IP
	m     map[string]*udpConn
}

func (cs *udpConns) dial(id, addr string) (*udpConn, bool, error) {
	cs.Lock()
	defer cs.Unlock()
	conn, ok := cs.m[id]
	if !ok {
		laddrIP := ""
		if cs.srcIP != nil {
			laddrIP = cs.srcIP.String()
		}
		laddr, err := net.ResolveUDPAddr("udp", laddrIP+":")
		if err != nil {
			fmt.Println(err)
			return nil, false, err
		}
		raddr, err := net.ResolveUDPAddr("udp", addr)
		if err != nil {
			fmt.Println(err)
			return nil, false, err
		}

		c, err := net.DialUDP("udp", laddr, raddr)
		if err != nil {
			return nil, false, err
		}
		conn = &udpConn{
			id:   id,
			Conn: c, // cnet.MeterConn(cs.Logger.Fork(addr), c),
		}
		cs.m[id] = conn
	}
	return conn, ok, nil
}

func (cs *udpConns) len() int {
	cs.Lock()
	l := len(cs.m)
	cs.Unlock()
	return l
}

func (cs *udpConns) remove(id string) {
	cs.Lock()
	delete(cs.m, id)
	cs.Unlock()
}

func (cs *udpConns) closeAll() {
	cs.Lock()
	for id, conn := range cs.m {
		conn.Close()
		delete(cs.m, id)
	}
	cs.Unlock()
}

type udpConn struct {
	id string
	net.Conn
}
