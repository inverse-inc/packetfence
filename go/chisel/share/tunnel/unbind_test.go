package tunnel

import (
	"context"
	"net"
	"strconv"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/chisel/share/cio"
	"github.com/inverse-inc/packetfence/go/chisel/share/settings"
)

func freePort(t *testing.T) string {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	return strconv.Itoa(l.Addr().(*net.TCPAddr).Port)
}

func waitFor(t *testing.T, what string, cond func() bool) {
	for deadline := time.Now().Add(5 * time.Second); time.Now().Before(deadline); time.Sleep(20 * time.Millisecond) {
		if cond() {
			return
		}
	}
	t.Fatalf("timed out waiting for %s", what)
}

func udpFree(port string) bool {
	c, err := net.ListenPacket("udp", "127.0.0.1:"+port)
	if err != nil {
		return false
	}
	c.Close()
	return true
}

// Unbinding one proxy of a BindRemotes group closes it alone: the UDP one
// ends with an error once cancelled (its ssh channel is gone), which must not
// take the rest of the group down.
func TestUnbindRemotes(t *testing.T) {
	tun := New(Config{Logger: cio.NewLogger("test"), Inbound: true})
	tcpPort, udpPort := freePort(t), freePort(t)
	keep, err := settings.DecodeRemote("R:127.0.0.1:" + tcpPort + ":192.0.2.53:53")
	if err != nil {
		t.Fatal(err)
	}
	drop, err := settings.DecodeRemote("R:127.0.0.1:" + udpPort + ":192.0.2.53:53/udp")
	if err != nil {
		t.Fatal(err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan error, 1)
	go func() { done <- tun.BindRemotes(ctx, []*settings.Remote{keep, drop}) }()
	waitFor(t, "both proxies bound", func() bool { return len(tun.BoundRemotes()) == 2 })

	// same remote, decoded again (as the server does from its configuration)
	again, _ := settings.DecodeRemote("R:127.0.0.1:" + udpPort + ":192.0.2.53:53/udp")
	if n, released := tun.UnbindRemotes([]*settings.Remote{again}, 3*time.Second); n != 1 || !released {
		t.Fatalf("UnbindRemotes closed %d proxies (released: %v), want 1", n, released)
	}
	// released on return: the port can be bound again right away
	if !udpFree(udpPort) {
		t.Fatalf("the unbound UDP port is still in use when UnbindRemotes returns")
	}
	if n := len(tun.BoundRemotes()); n != 1 {
		t.Fatalf("%d bound proxies, want 1", n)
	}

	remotes := tun.BoundRemotes()
	if remotes[0].LocalPort != tcpPort || remotes[0].LocalProto != "tcp" {
		t.Errorf("bound remotes after unbind: %+v", remotes)
	}
	if c, err := net.Dial("tcp", "127.0.0.1:"+tcpPort); err != nil {
		t.Errorf("the other proxy of the group is no longer listening: %s", err)
	} else {
		c.Close()
	}
	select {
	case err := <-done:
		t.Fatalf("BindRemotes returned after unbinding one proxy: %v", err)
	default:
	}

	if n, _ := tun.UnbindRemotes([]*settings.Remote{again}, time.Second); n != 0 {
		t.Errorf("unbinding an unbound remote closed %d proxies", n)
	}
}

func tcpFree(port string) bool {
	l, err := net.Listen("tcp", "127.0.0.1:"+port)
	if err != nil {
		return false
	}
	l.Close()
	return true
}

// A remote that can't listen fails the batch without leaving the listeners
// opened before it bound.
func TestStartRemotesListenError(t *testing.T) {
	tun := New(Config{Logger: cio.NewLogger("test"), Inbound: true})
	freeTCP := freePort(t)
	busy, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer busy.Close()
	busyPort := strconv.Itoa(busy.Addr().(*net.TCPAddr).Port)
	first, _ := settings.DecodeRemote("R:127.0.0.1:" + freeTCP + ":192.0.2.53:53")
	second, _ := settings.DecodeRemote("R:127.0.0.1:" + busyPort + ":192.0.2.53:53")

	if _, err := tun.startRemotes(context.Background(), []*settings.Remote{first, second}); err == nil {
		t.Fatal("startRemotes succeeded on a port in use")
	}
	if !tcpFree(freeTCP) {
		t.Errorf("the listener opened before the failing one was left open")
	}
	if n := len(tun.BoundRemotes()); n != 0 {
		t.Errorf("%d bound proxies after a failed start", n)
	}
}

// WaitUnbound returns once the listeners of a stopped tunnel are released.
func TestWaitUnbound(t *testing.T) {
	tun := New(Config{Logger: cio.NewLogger("test"), Inbound: true})
	tcpPort, udpPort := freePort(t), freePort(t)
	r1, _ := settings.DecodeRemote("R:127.0.0.1:" + tcpPort + ":192.0.2.53:53")
	r2, _ := settings.DecodeRemote("R:127.0.0.1:" + udpPort + ":192.0.2.53:53/udp")
	ctx, cancel := context.WithCancel(context.Background())
	wait, err := tun.startRemotes(ctx, []*settings.Remote{r1, r2})
	if err != nil {
		t.Fatal(err)
	}
	go wait()
	cancel()
	if !tun.WaitUnbound(3 * time.Second) {
		t.Fatal("the listeners were not released")
	}
	if !tcpFree(tcpPort) || !udpFree(udpPort) {
		t.Errorf("a port is still in use after WaitUnbound")
	}
}
