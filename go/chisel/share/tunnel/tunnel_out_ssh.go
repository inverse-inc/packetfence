package tunnel

import (
	"fmt"
	"io"
	"net"
	"strings"
	"sync"

	"github.com/inverse-inc/packetfence/go/chisel/share/cio"
	"github.com/inverse-inc/packetfence/go/chisel/share/cnet"
	"github.com/inverse-inc/packetfence/go/chisel/share/settings"
	"github.com/jpillora/sizestr"
	"golang.org/x/crypto/ssh"
)

func (t *Tunnel) handleSSHRequests(reqs <-chan *ssh.Request) {
	for r := range reqs {
		switch r.Type {
		case "ping":
			r.Reply(true, []byte("pong"))
		default:
			t.Debugf("Unknown request: %s", r.Type)
		}
	}
}

func (t *Tunnel) handleSSHChannels(chans <-chan ssh.NewChannel) {
	for ch := range chans {
		go t.handleSSHChannel(ch)
	}
}

func (t *Tunnel) handleSSHChannel(ch ssh.NewChannel) {
	if !t.Config.Outbound {
		t.Debugf("Denied outbound connection")
		ch.Reject(ssh.Prohibited, "Denied outbound connection")
		return
	}

	remote := string(ch.ExtraData())
	//extract protocol(s)
	hostPort, protocols, handler := settings.L4Proto(remote)

	socks := hostPort == "socks"
	if socks && t.socksServer == nil {
		t.Debugf("Denied socks request, please enable socks")
		ch.Reject(ssh.Prohibited, "SOCKS5 is not enabled")
		return
	}

	sshChan, reqs, err := ch.Accept()
	if err != nil {
		t.Debugf("Failed to accept stream: %s", err)
		return
	}
	stream := io.ReadWriteCloser(sshChan)
	defer stream.Close()
	go ssh.DiscardRequests(reqs)

	l := t.Logger.Fork("conn#%d", t.connStats.New())
	//ready to handle
	t.connStats.Open()
	l.Debugf("Open %s", t.connStats.String())

	if socks {
		err = t.handleSocks(stream)
	} else {
		err = t.handleProtocols(l, stream, hostPort, protocols, handler)
	}

	t.connStats.Close()
	errmsg := ""
	if err != nil && !strings.HasSuffix(err.Error(), "EOF") {
		errmsg = fmt.Sprintf(" (error %s)", err)
	}
	l.Debugf("Close %s%s", t.connStats.String(), errmsg)
}

func (t *Tunnel) handleProtocols(l *cio.Logger, stream io.ReadWriteCloser, hostPort string, protocols []string, handler string) error {
	// Handle dual stack or multiple protocols
	if len(protocols) == 0 {
		// Default to TCP for backward compatibility
		return t.handleTCP(l, stream, hostPort)
	}

	if len(protocols) == 1 {
		// Single protocol - use existing handlers
		switch protocols[0] {
		case "tcp":
			return t.handleTCP(l, stream, hostPort)
		case "udp":
			return t.handleUDP(l, stream, hostPort, handler)
		case "dual":
			// Dual stack specified - handle both
			return t.handleDualStack(l, stream, hostPort, handler)
		default:
			return fmt.Errorf("unsupported protocol: %s", protocols[0])
		}
	}

	// Multiple protocols specified - handle as dual stack
	return t.handleDualStack(l, stream, hostPort, handler)
}

func (t *Tunnel) handleDualStack(l *cio.Logger, stream io.ReadWriteCloser, hostPort string, handler string) error {
	// For dual stack, we need to determine the protocol dynamically
	// This could be done by examining the first few bytes of the stream
	// or by using a protocol multiplexer

	// Simple approach: try to detect the protocol based on the first packet
	// Create a buffered reader to peek at the data
	bufferedStream := &protocolDetector{
		stream: stream,
		buffer: make([]byte, 0, 1024),
	}

	// Try to detect the protocol
	protocol, err := bufferedStream.detectProtocol()
	if err != nil {
		l.Debugf("Failed to detect protocol for dual stack: %s", err)
		// Fall back to TCP as default
		return t.handleTCP(l, bufferedStream, hostPort)
	}

	l.Debugf("Detected protocol: %s for dual stack connection", protocol)

	switch protocol {
	case "tcp":
		return t.handleTCP(l, bufferedStream, hostPort)
	case "udp":
		return t.handleUDP(l, bufferedStream, hostPort, handler)
	default:
		return t.handleTCP(l, bufferedStream, hostPort) // Default fallback
	}
}

// protocolDetector helps detect the protocol for dual stack connections
type protocolDetector struct {
	stream io.ReadWriteCloser
	buffer []byte
	mutex  sync.Mutex
	peeked bool
}

func (pd *protocolDetector) detectProtocol() (string, error) {
	pd.mutex.Lock()
	defer pd.mutex.Unlock()

	if pd.peeked {
		// Already detected
		return "tcp", nil // Default assumption after peek
	}

	// Read a small amount of data to detect protocol
	tempBuf := make([]byte, 16)
	n, err := pd.stream.Read(tempBuf)
	if err != nil {
		return "", err
	}

	pd.buffer = append(pd.buffer, tempBuf[:n]...)
	pd.peeked = true

	// Simple heuristic: if data looks like HTTP or other text protocols, assume TCP
	// If it looks like binary data or DNS queries, it might be UDP
	// This is a simplified detection - in practice, you might need more sophisticated logic

	if n > 0 {
		firstByte := tempBuf[0]
		// Simple heuristics:
		// - HTTP methods start with uppercase letters
		// - DNS queries have specific patterns
		// - Binary protocols might have different patterns

		if firstByte >= 'A' && firstByte <= 'Z' {
			return "tcp", nil // Likely HTTP or similar text protocol
		}

		// Check for DNS query pattern (very basic)
		if n >= 12 && (firstByte&0x80) == 0 { // DNS query flag
			return "udp", nil
		}
	}

	// Default to TCP
	return "tcp", nil
}

func (pd *protocolDetector) Read(p []byte) (int, error) {
	pd.mutex.Lock()
	defer pd.mutex.Unlock()

	// If we have buffered data, return that first
	if len(pd.buffer) > 0 {
		n := copy(p, pd.buffer)
		pd.buffer = pd.buffer[n:]
		if n == len(p) || len(pd.buffer) == 0 {
			return n, nil
		}
		// Need more data
		remaining := p[n:]
		moreRead, err := pd.stream.Read(remaining)
		return n + moreRead, err
	}

	// No buffered data, read directly
	return pd.stream.Read(p)
}

func (pd *protocolDetector) Write(p []byte) (int, error) {
	return pd.stream.Write(p)
}

func (pd *protocolDetector) Close() error {
	return pd.stream.Close()
}

func (t *Tunnel) handleSocks(src io.ReadWriteCloser) error {
	return t.socksServer.ServeConn(cnet.NewRWCConn(src))
}

func (t *Tunnel) handleTCP(l *cio.Logger, src io.ReadWriteCloser, hostPort string) error {
	laddrIP := ""
	if t.Config.SrcIP != nil {
		laddrIP = t.Config.SrcIP.String()
	}
	laddr, err := net.ResolveTCPAddr("tcp", laddrIP+":")
	if err != nil {
		l.Debugf("TCP resolve local addr error: %v", err)
		return err
	}
	raddr, err := net.ResolveTCPAddr("tcp", hostPort)
	if err != nil {
		l.Debugf("TCP resolve remote addr error: %v", err)
		return err
	}
	dst, err := net.DialTCP("tcp", laddr, raddr)
	if err != nil {
		l.Debugf("TCP dial error: %v", err)
		return err
	}
	defer dst.Close()

	s, r := cio.Pipe(src, dst)
	l.Debugf("TCP: sent %s received %s", sizestr.ToString(s), sizestr.ToString(r))
	return nil
}

func (t *Tunnel) handleUDP(l *cio.Logger, src io.ReadWriteCloser, hostPort string, handler string) error {
	laddrIP := ""
	if t.Config.SrcIP != nil {
		laddrIP = t.Config.SrcIP.String()
	}
	laddr, err := net.ResolveUDPAddr("udp", laddrIP+":")
	if err != nil {
		l.Debugf("UDP resolve local addr error: %v", err)
		return err
	}
	raddr, err := net.ResolveUDPAddr("udp", hostPort)
	if err != nil {
		l.Debugf("UDP resolve remote addr error: %v", err)
		return err
	}
	dst, err := net.DialUDP("udp", laddr, raddr)
	if err != nil {
		l.Debugf("UDP dial error: %v", err)
		return err
	}
	defer dst.Close()

	s, r := cio.Pipe(src, dst)
	l.Debugf("UDP: sent %s received %s", sizestr.ToString(s), sizestr.ToString(r))
	return nil
}
