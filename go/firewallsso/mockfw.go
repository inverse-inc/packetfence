package firewallsso

import (
	"context"
	"github.com/fingerbank/processor/log"
)

type MockFW struct {
	FirewallSSO
}

func (mfw *MockFW) Start(ctx context.Context, info map[string]string, timeout int) bool {
	log.LoggerWContext(ctx).Info("Sending SSO through mocked Firewall SSO")
	return true
}

func (mfw *MockFW) Stop(ctx context.Context, info map[string]string) bool {
	log.LoggerWContext(ctx).Info("Sending SSO through mocked Firewall SSO")
	return true
}
