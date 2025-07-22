package tunnel

import (
	"context"
	"io"
	"net"
	"sync/atomic"
	"time"

	"github.com/inverse-inc/packetfence/go/chisel/share/cio"
	"github.com/inverse-inc/packetfence/go/chisel/share/settings"
	"github.com/jpillora/sizestr"
	"golang.org/x/crypto/ssh"
)

const INACTIVITY_CHECK_INTERVAL = 60 * time.Second
const LAST_TOUCHED_TIMEOUT = 10 * time.Second

// sshTunnel exposes a subset of Tunnel to subtypes
type sshTunnel interface {
	getSSH(ctx context.Context) ssh.Conn
}

// Proxy is the inbound portion of a Tunnel
type Proxy struct {
	*cio.Logger
	sshTun     sshTunnel
	id         int
	count      int
	remote     *settings.Remote
	dialer     net.Dialer
	tcp        *net.TCPListener
	udp        *udpListener
	aliveConns int64
	dualStack  bool // Track if this is a dual stack proxy
}

// NewProxy creates a Proxy
func NewProxy(logger *cio.Logger, sshTun sshTunnel, index int, remote *settings.Remote) (*Proxy, error) {
	id := index + 1
	p := &Proxy{
		Logger:    logger.Fork("proxy#%s", remote.String()),
		sshTun:    sshTun,
		id:        id,
		remote:    remote,
		dualStack: remote.IsDualStack(),
	}
	return p, p.listen()
}

func (p *Proxy) listen() error {
	if p.remote.Stdio {
		//TODO check if pipes active?
		return nil
	}

	protocols := p.remote.GetLocalProtocols()

	// Handle dual stack or multiple protocols
	for _, protocol := range protocols {
		switch protocol {
		case "tcp":
			if err := p.listenTCP(); err != nil {
				return err
			}
		case "udp":
			if err := p.listenUDP(); err != nil {
				return err
			}
		default:
			return p.Errorf("unknown local proto: %s", protocol)
		}
	}

	if len(protocols) == 0 {
		return p.Errorf("no protocols specified")
	}

	return nil
}

func (p *Proxy) listenTCP() error {
	if p.remote.ReusedTcpListener != nil {
		p.tcp = p.remote.ReusedTcpListener
		p.remote.ReusedTcpListener = nil
	} else {
		addr, err := net.ResolveTCPAddr("tcp", p.remote.LocalHost+":"+p.remote.LocalPort)
		if err != nil {
			return p.Errorf("resolve TCP: %s", err)
		}
		l, err := net.ListenTCP("tcp", addr)
		if err != nil {
			return p.Errorf("tcp listen: %s", err)
		}
		p.Infof("Listening on TCP")
		p.tcp = l
	}
	return nil
}

func (p *Proxy) listenUDP() error {
	if p.remote.ReusedUdpConn != nil {
		// Create udpListener wrapper around the reused connection
		p.udp = &udpListener{
			conn:   p.remote.ReusedUdpConn,
			logger: p.Logger,
			sshTun: p.sshTun,
			remote: p.remote,
		}
		p.remote.ReusedUdpConn = nil
	} else {
		l, err := listenUDP(p.Logger, p.sshTun, p.remote)
		if err != nil {
			return p.Errorf("udp listen: %s", err)
		}
		p.Infof("Listening on UDP")
		p.udp = l
	}
	return nil
}

// Run enables the proxy and blocks while its active,
// close the proxy by cancelling the context.
func (p *Proxy) Run(ctx context.Context) error {
	if p.remote.Stdio {
		return p.runStdio(ctx)
	}

	protocols := p.remote.GetLocalProtocols()

	if p.dualStack || len(protocols) > 1 {
		return p.runDualStack(ctx)
	}

	// Single protocol mode (backward compatibility)
	if len(protocols) == 1 {
		switch protocols[0] {
		case "tcp":
			return p.runTCP(ctx)
		case "udp":
			return p.udp.run(ctx)
		}
	}

	return p.Errorf("no valid protocols to run")
}

func (p *Proxy) runDualStack(ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	protocols := p.remote.GetLocalProtocols()
	errChan := make(chan error, len(protocols))

	// Start goroutines for each protocol
	for _, protocol := range protocols {
		switch protocol {
		case "tcp":
			if p.tcp != nil {
				go func() {
					err := p.runTCP(ctx)
					errChan <- err
				}()
			}
		case "udp":
			if p.udp != nil {
				go func() {
					err := p.udp.run(ctx)
					errChan <- err
				}()
			}
		}
	}

	// Wait for any protocol to error or context cancellation
	select {
	case err := <-errChan:
		p.Infof("Protocol handler exited: %v", err)
		return err
	case <-ctx.Done():
		p.Infof("Context cancelled, shutting down dual stack proxy")
		return ctx.Err()
	}
}

func (p *Proxy) runStdio(ctx context.Context) error {
	defer p.Infof("Closed")
	for {
		p.pipeRemote(ctx, cio.Stdio)
		select {
		case <-ctx.Done():
			return nil
		default:
			// the connection is not ready yet, keep waiting
		}
	}
}

func (p *Proxy) runTCP(ctx context.Context) error {
	if p.tcp == nil {
		return p.Errorf("TCP listener not initialized")
	}

	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	done := make(chan struct{})

	//implements missing net.ListenContext
	go func() {
		select {
		case <-ctx.Done():
			p.tcp.Close()
		case <-done:
		}
	}()

	srcChan := make(chan net.Conn)
	errChan := make(chan error)

	go func() {
		defer close(done)
		for {
			src, err := p.tcp.Accept()
			if err == nil {
				srcChan <- src
			} else {
				select {
				case <-ctx.Done():
					//listener closed
					p.Infof("TCP listener closed")
					err = nil
				default:
					p.Infof("TCP Accept error: %s", err)
				}
				errChan <- err
				return
			}
		}
	}()

	for {
		select {
		case err := <-errChan:
			return err
		case src := <-srcChan:
			atomic.AddInt64(&p.aliveConns, 1)
			go p.pipeRemote(ctx, src)
		case <-time.After(INACTIVITY_CHECK_INTERVAL):
			shouldReturn := func() bool {
				p.remote.Lock()
				defer p.remote.Unlock()

				if p.remote.Dynamic {
					if time.Since(p.remote.LastTouched) > LAST_TOUCHED_TIMEOUT {
						if atomic.LoadInt64(&p.aliveConns) == 0 {
							return true
						}
					}
				}
				return false
			}()
			if shouldReturn {
				if settings.ClearFromActiveDynReverse(p.remote) {
					// We've cleared it from the cache, we'll continue monitoring the inactivity of the connection just in case it got sent just before the cache clear
					p.Infof("Cleared entry from active dynamic reverses")
					continue
				}

				p.Infof("Closing TCP due to inactivity timeout")
				p.tcp.Close()
				return nil
			}
		}
	}
}

func (p *Proxy) pipeRemote(ctx context.Context, src io.ReadWriteCloser) {
	defer func() {
		atomic.AddInt64(&p.aliveConns, -1)
		src.Close()
	}()
	p.count++
	cid := p.count
	l := p.Fork("conn#%d", cid)
	l.Debugf("Open")
	sshConn := p.sshTun.getSSH(ctx)
	if sshConn == nil {
		l.Errorf("No remote connection")
		return
	}

	//ssh request for tcp connection for this proxy's remote
	dst, reqs, err := sshConn.OpenChannel("chisel", []byte(p.remote.Remote()))
	if err != nil {
		l.Infof("Stream error: %s", err)
		return
	}
	go ssh.DiscardRequests(reqs)

	//then pipe
	s, r := cio.Pipe(src, dst)
	l.Debugf("Close (sent %s received %s)", sizestr.ToString(s), sizestr.ToString(r))
}

// Close gracefully closes the proxy
func (p *Proxy) Close() error {
	var tcpErr, udpErr error

	if p.tcp != nil {
		tcpErr = p.tcp.Close()
	}

	if p.udp != nil {
		udpErr = p.udp.Close()
	}

	// Return the first error encountered
	if tcpErr != nil {
		return tcpErr
	}
	return udpErr
}

// GetLocalAddr returns the local address for the specified protocol
func (p *Proxy) GetLocalAddr(protocol string) net.Addr {
	switch protocol {
	case "tcp":
		if p.tcp != nil {
			return p.tcp.Addr()
		}
	case "udp":
		if p.udp != nil && p.udp.conn != nil {
			return p.udp.conn.LocalAddr()
		}
	}
	return nil
}

// IsListening returns whether the proxy is listening on the specified protocol
func (p *Proxy) IsListening(protocol string) bool {
	switch protocol {
	case "tcp":
		return p.tcp != nil
	case "udp":
		return p.udp != nil
	default:
		return false
	}
}

// GetProtocols returns the protocols this proxy supports
func (p *Proxy) GetProtocols() []string {
	return p.remote.GetLocalProtocols()
}
