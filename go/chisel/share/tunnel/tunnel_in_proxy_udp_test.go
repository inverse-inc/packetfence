package tunnel

import (
	"context"
	"fmt"
	"io"
	"net"
	"sync"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/chisel/share/cio"
	"github.com/inverse-inc/packetfence/go/chisel/share/settings"
	"golang.org/x/crypto/ssh"
)

// fakeUDPChannel is the connector end of a UDP forward that never answers:
// reads block until the channel is closed.
type fakeUDPChannel struct {
	net.Conn
	peer net.Conn
}

func (c *fakeUDPChannel) Close() error {
	c.peer.Close()
	return c.Conn.Close()
}
func (c *fakeUDPChannel) CloseWrite() error { return nil }
func (c *fakeUDPChannel) SendRequest(string, bool, []byte) (bool, error) {
	return false, nil
}
func (c *fakeUDPChannel) Stderr() io.ReadWriter { return nil }

type fakeSSHConn struct {
	ssh.Conn
	opened chan struct{}
	once   sync.Once
	done   chan struct{}
}

func (c *fakeSSHConn) OpenChannel(string, []byte) (ssh.Channel, <-chan *ssh.Request, error) {
	a, b := net.Pipe()
	// drain what the listener forwards
	go io.Copy(io.Discard, b)
	c.once.Do(func() { close(c.opened) })
	return &fakeUDPChannel{Conn: a, peer: b}, make(chan *ssh.Request), nil
}
func (c *fakeSSHConn) Wait() error {
	<-c.done
	return nil
}

type fakeSSHTunnel struct{ conn *fakeSSHConn }

func (t *fakeSSHTunnel) serviceStats(string) *serviceCounters { return nil }

// getSSH returns no connection once ctx is done, like Tunnel.getSSH.
func (t *fakeSSHTunnel) getSSH(ctx context.Context) ssh.Conn {
	if isDone(ctx) {
		return nil
	}
	return t.conn
}

// A UDP listener that carried traffic must close as soon as its context is
// cancelled, dynamic (port picked by the server) or not (the containers
// gateway companion of a dynreverse): its outbound loop is blocked reading the
// ssh channel and only returns once that channel is closed, and the
// inactivity check of a dynamic one must not hold it either.
func TestUDPListenerClosesOnCancel(t *testing.T) {
	free, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatal(err)
	}
	explicit := free.LocalAddr().(*net.UDPAddr).Port
	free.Close()
	for _, spec := range []string{
		"R:127.0.0.1:0:192.0.2.12:161/udp",
		fmt.Sprintf("R:127.0.0.1:%d:192.0.2.12:161/udp", explicit),
	} {
		t.Run(spec, func(t *testing.T) { testUDPListenerClosesOnCancel(t, spec) })
	}
}

func testUDPListenerClosesOnCancel(t *testing.T, spec string) {
	conn := &fakeSSHConn{opened: make(chan struct{}), done: make(chan struct{})}
	defer close(conn.done)
	remote, err := settings.DecodeRemote(spec)
	if err != nil {
		t.Fatal(err)
	}
	u, err := listenUDP(cio.NewLogger("test"), &fakeSSHTunnel{conn: conn}, remote)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ran := make(chan error, 1)
	go func() { ran <- u.run(ctx) }()

	client, err := net.DialUDP("udp", nil, u.inbound.LocalAddr().(*net.UDPAddr))
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	if _, err := client.Write([]byte("get-request")); err != nil {
		t.Fatal(err)
	}
	select {
	case <-conn.opened:
	case <-time.After(5 * time.Second):
		t.Fatal("no ssh channel opened for the forwarded packet")
	}

	cancel()
	select {
	case <-ran:
	case <-time.After(5 * time.Second):
		t.Fatal("the listener is still running after its context was cancelled")
	}
}
