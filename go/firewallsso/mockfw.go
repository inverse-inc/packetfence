package firewallsso

import (
	"context"
	"github.com/fingerbank/processor/log"
)

type MockFW struct {
	FirewallSSO
}

func (mfw *MockFW) Start(ctx context.Context, info map[string]string, timeout int) (bool, error) {
	log.LoggerWContext(ctx).Info("Sending SSO through mocked Firewall SSO")
	return true, nil
}

func (mfw *MockFW) Stop(ctx context.Context, info map[string]string) (bool, error) {
	log.LoggerWContext(ctx).Info("Sending SSO through mocked Firewall SSO")
	return true, nil
}
