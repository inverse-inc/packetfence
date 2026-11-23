package pfpki

import (
	"context"
	"testing"
	"time"

	"github.com/caddyserver/caddy/v2"
	"gorm.io/gorm"
)

// Caddy only calls Cleanup after Provision returns, so a database wait inside
// Provision must stop when caddy cancels the provisioning context (config
// unload or shutdown), not on something Cleanup cancels.
func TestProvisionStopsWaitingWhenCaddyContextIsCancelled(t *testing.T) {
	old := waitForDB
	waitForDB = func(ctx context.Context, _ time.Duration) (*gorm.DB, error) {
		<-ctx.Done()
		return nil, ctx.Err()
	}
	t.Cleanup(func() { waitForDB = old })

	cctx, cancel := caddy.NewContext(caddy.Context{Context: context.Background()})
	h := &Handler{}
	done := make(chan error, 1)
	go func() { done <- h.Provision(cctx) }()

	time.Sleep(20 * time.Millisecond)
	cancel()
	select {
	case err := <-done:
		if err == nil {
			t.Fatal("Provision succeeded without a database")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("Provision kept waiting after caddy cancelled its context")
	}
}
