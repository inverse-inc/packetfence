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
}

// NewProxy creates a Proxy
func NewProxy(logger *cio.Logger, sshTun sshTunnel, index int, remote *settings.Remote) (*Proxy, error) {
	id := index + 1
	p := &Proxy{
		Logger: logger.Fork("proxy#%s", remote.String()),
		sshTun: sshTun,
		id:     id,
		remote: remote,
	}
	return p, p.listen()
}

func (p *Proxy) listen() error {
	if p.remote.Stdio {
		//TODO check if pipes active?
	} else if p.remote.LocalProto == "tcp" {
		if p.remote.ReusedTcpListener != nil {
			p.tcp = p.remote.ReusedTcpListener
			p.remote.ReusedTcpListener = nil
		} else {
			addr, err := net.ResolveTCPAddr("tcp", p.remote.LocalHost+":"+p.remote.LocalPort)
			if err != nil {
				return p.Errorf("resolve: %s", err)
			}
			l, err := net.ListenTCP("tcp", addr)
			if err != nil {
				return p.Errorf("tcp: %s", err)
			}
			p.Infof("Listening")
			p.tcp = l
		}
	} else if p.remote.LocalProto == "udp" {
		l, err := listenUDP(p.Logger, p.sshTun, p.remote)
		if err != nil {
			return err
		}
		p.Infof("Listening")
		p.udp = l
	} else {
		return p.Errorf("unknown local proto")
	}
	return nil
}

// Run enables the proxy and blocks while its active,
// close the proxy by cancelling the context.
func (p *Proxy) Run(ctx context.Context) error {
	if p.remote.Stdio {
		return p.runStdio(ctx)
	} else if p.remote.LocalProto == "tcp" {
		return p.runTCP(ctx)
	} else if p.remote.LocalProto == "udp" {
		return p.udp.run(ctx)
	}
	panic("should not get here")
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
		for {
			src, err := p.tcp.Accept()
			if err == nil {
				srcChan <- src
			} else {
				select {
				case <-ctx.Done():
					//listener closed
					p.Infof("listener closed", err)
					err = nil
				default:
					p.Infof("Accept error: %s", err)
				}
				close(done)
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

				p.Infof("Closing due to inactivity timeout")
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
