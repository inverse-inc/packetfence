package firewallsso

import (
	"context"
	"github.com/inverse-inc/go-utils/log"
)

// A mock FW for use in unit tests
type MockFW struct {
	FirewallSSO
}

// Send a dummy SSO start
// This will always succeed without any error
func (mfw *MockFW) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	log.LoggerWContext(ctx).Info("Sending SSO through mocked Firewall SSO")
	return true, nil
}

// Send a dummy SSO stop
// This will always succeed without any error
func (mfw *MockFW) Stop(ctx context.Context, info map[string]string) (bool, error) {
	log.LoggerWContext(ctx).Info("Sending SSO through mocked Firewall SSO")
	return true, nil
}
