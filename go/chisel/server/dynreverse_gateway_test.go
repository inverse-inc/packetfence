package chserver

import (
	"context"
	"net"
	"strconv"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/chisel/share/cio"
	"github.com/inverse-inc/packetfence/go/chisel/share/settings"
	"github.com/inverse-inc/packetfence/go/chisel/share/tunnel"
)

// The containers gateway listener is only added for classic containers on a
// bridge network.
func TestDynReverseGatewayHost(t *testing.T) {
	t.Setenv("PFCONNECTOR_SERVER_DYN_REVERSE_GATEWAY", "100.64.0.1")
	t.Setenv("IS_A_CLASSIC_PF_CONTAINER", "")
	t.Setenv("DOCKER_NETWORK_IS_HOST", "")
	if got := dynReverseGatewayHost(); got != "" {
		t.Errorf("not a classic container: %q", got)
	}
	t.Setenv("IS_A_CLASSIC_PF_CONTAINER", "yes")
	if got := dynReverseGatewayHost(); got != "100.64.0.1" {
		t.Errorf("classic container: %q", got)
	}
	t.Setenv("DOCKER_NETWORK_IS_HOST", "yes")
	if got := dynReverseGatewayHost(); got != "" {
		t.Errorf("host network: %q", got)
	}
	t.Setenv("DOCKER_NETWORK_IS_HOST", "")
	t.Setenv("PFCONNECTOR_SERVER_DYN_REVERSE_GATEWAY", "2001:db8::1")
	if got := dynReverseGatewayHost(); got != "" {
		t.Errorf("IPv6 gateway: %q", got)
	}
}

// The companion listener lives exactly as long as the primary: it stays bound
// past the inactivity timeout of a dynamic reverse, and closes as soon as the
// primary's context ends.
func TestDynReverseGatewayCompanionLifetime(t *testing.T) {
	t.Setenv("PFCONNECTOR_SERVER_DYN_REVERSE_GATEWAY", "127.0.0.1")
	t.Setenv("IS_A_CLASSIC_PF_CONTAINER", "yes")
	t.Setenv("DOCKER_NETWORK_IS_HOST", "")

	free, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatal(err)
	}
	port := strconv.Itoa(free.LocalAddr().(*net.UDPAddr).Port)
	free.Close()
	bound := func() bool {
		c, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: free.LocalAddr().(*net.UDPAddr).Port})
		if err != nil {
			return true
		}
		c.Close()
		return false
	}
	waitFor := func(want bool) bool {
		for deadline := time.Now().Add(5 * time.Second); time.Now().Before(deadline); time.Sleep(50 * time.Millisecond) {
			if bound() == want {
				return true
			}
		}
		return false
	}

	tun := tunnel.New(tunnel.Config{Logger: cio.NewLogger("test"), Inbound: true})
	primary := &settings.Remote{}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	bindDynReverseGatewayCompanion(ctx, tun, primary, "192.0.2.1:", port, "192.0.2.12:161/udp")
	if !waitFor(true) {
		t.Fatalf("the companion is not bound on 127.0.0.1:%s", port)
	}
	if remotes := tun.BoundRemotes(); len(remotes) != 1 || remotes[0].LocalHost != "127.0.0.1" || remotes[0].LocalPort != port {
		t.Fatalf("bound remotes: %+v", remotes)
	}
	time.Sleep(200 * time.Millisecond)
	if !bound() {
		t.Fatalf("the companion closed on its own")
	}
	cancel()
	if !waitFor(false) {
		t.Fatalf("the companion is still bound after the primary closed")
	}
	if remotes := tun.BoundRemotes(); len(remotes) != 0 {
		t.Errorf("bound remotes after close: %+v", remotes)
	}

	// No companion when the primary is already on the gateway.
	ctx2, cancel2 := context.WithCancel(context.Background())
	defer cancel2()
	bindDynReverseGatewayCompanion(ctx2, tun, primary, "127.0.0.1:", port, "192.0.2.12:161/udp")
	time.Sleep(200 * time.Millisecond)
	if bound() {
		t.Errorf("a companion was bound on the primary's own address")
	}
}
