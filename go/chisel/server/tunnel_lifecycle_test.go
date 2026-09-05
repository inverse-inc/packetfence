package chserver

import (
	"testing"

	"github.com/inverse-inc/packetfence/go/chisel/share/cio"
	"github.com/inverse-inc/packetfence/go/chisel/share/tunnel"
	"github.com/redis/go-redis/v9"
)

// releaseTunnel must forget a closed tunnel but never a newer tunnel that
// already replaced it for the same connector id (reconnect / HA failover).
func TestReleaseTunnelKeepsNewerTunnel(t *testing.T) {
	s := &Server{
		Logger: cio.NewLogger("test"),
		// unreachable on purpose: the Redis part must degrade to a no-op
		redis:                 redis.NewClient(&redis.Options{Addr: "127.0.0.1:1", MaxRetries: 0}),
		redisTunnelsNamespace: "test:activeTunnels:",
	}
	const id = "connector-ha-test"
	old := tunnel.New(tunnel.Config{Logger: cio.NewLogger("old")})
	newer := tunnel.New(tunnel.Config{Logger: cio.NewLogger("new")})
	t.Cleanup(func() { activeTunnels.Delete(id) })

	activeTunnels.Store(id, old)
	activeTunnels.Store(id, newer) // the reconnecting host took over

	s.releaseTunnel(id, old, "http://old-instance")
	if v, ok := activeTunnels.Load(id); !ok || v != newer {
		t.Fatalf("stale teardown removed the newer tunnel: present=%v", ok)
	}

	s.releaseTunnel(id, newer, "http://new-instance")
	if _, ok := activeTunnels.Load(id); ok {
		t.Fatalf("closing the current tunnel must remove the activeTunnels entry")
	}
}

// Close on a tunnel that never bound an SSH connection is a no-op.
func TestTunnelCloseWithoutConnection(t *testing.T) {
	tun := tunnel.New(tunnel.Config{Logger: cio.NewLogger("t")})
	if err := tun.Close(); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if tun.IsActive() {
		t.Fatalf("tunnel must not be active")
	}
}
