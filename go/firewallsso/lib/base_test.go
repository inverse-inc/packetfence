package libfirewallsso

import (
	"context"
	"github.com/inverse-inc/packetfence/go/logging"
	"github.com/inverse-inc/packetfence/go/util"
	"testing"
)

var ctx = logging.NewContext(context.Background())

func TestStart(t *testing.T) {
	factory := NewFactory(ctx)
	o, err := factory.Instantiate(ctx, "testfw")
	util.CheckTestError(t, err)
	iboss := o.(*Iboss)

	if err == nil {
		result := ExecuteStart(ctx, iboss, map[string]string{"ip": "172.20.0.1", "role": "default", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)
		if !result {
			t.Error("Iboss SSO didn't succeed with valid parameters")
		}

		// invalid role, invalid IP
		result = ExecuteStart(ctx, iboss, map[string]string{"ip": "1.2.3.4", "role": "no-sso-on-that", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)
		if result {
			t.Error("Iboss SSO succeeded with invalid parameters")
		}

		// valid role, invalid IP
		result = ExecuteStart(ctx, iboss, map[string]string{"ip": "1.2.3.4", "role": "default", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)
		if result {
			t.Error("Iboss SSO succeeded with invalid parameters")
		}
	}

	paloalto, err := factory.Instantiate(ctx, "paloalto.com")
	util.CheckTestError(t, err)

	if err == nil {
		result := ExecuteStart(ctx, paloalto, map[string]string{"ip": "172.20.0.1", "role": "gaming", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)

		if !result {
			t.Error("PaloAlto SSO failed with valid parameters")
		}

		// invalid role, IP doesn't matter
		result = ExecuteStart(ctx, paloalto, map[string]string{"ip": "1.2.3.4", "role": "no-sso-on-that", "mac": "00:11:22:33:44:55", "username": "lzammit"}, 0)

		if result {
			t.Error("PaloAlto SSO succeeded with invalid parameters")
		}
	}
}

func TestMatchesNetwork(t *testing.T) {
	factory := NewFactory(ctx)

	// Test firewall that has 1 or more network assigned to it
	fw, err := factory.Instantiate(ctx, "testfw")
	util.CheckTestError(t, err)

	if err == nil {
		if fw.MatchesNetwork(ctx, map[string]string{"ip": "1.2.3.4"}) {
			t.Error("Firewall matches network when it shouldn't")
		}
		if !fw.MatchesNetwork(ctx, map[string]string{"ip": "172.20.20.1"}) {
			t.Error("Firewall doesn't match network when it should")
		}
		if !fw.MatchesNetwork(ctx, map[string]string{"ip": "192.168.0.28"}) {
			t.Error("Firewall doesn't match network when it should")
		}
	}

	// Test firewall that has no network assigned to it
	fw, err = factory.Instantiate(ctx, "testfw2")
	util.CheckTestError(t, err)

	if err == nil {
		if !fw.MatchesNetwork(ctx, map[string]string{"ip": "1.2.3.4"}) {
			t.Error("Firewall doesn't match network when it should")
		}
		if !fw.MatchesNetwork(ctx, map[string]string{"ip": "172.20.20.1"}) {
			t.Error("Firewall doesn't match network when it should")
		}
		if !fw.MatchesNetwork(ctx, map[string]string{"ip": "192.168.0.28"}) {
			t.Error("Firewall doesn't match network when it should")
		}
	}
}

func TestMatchesRole(t *testing.T) {
	factory := NewFactory(ctx)

	// Test firewall that has 1 or more role assigned to it
	fw, err := factory.Instantiate(ctx, "testfw2")
	util.CheckTestError(t, err)

	if err == nil {
		if fw.MatchesRole(ctx, map[string]string{"role": "no-sso"}) {
			t.Error("Firewall matches role when it shouldn't")
		}

		if !fw.MatchesRole(ctx, map[string]string{"role": "default"}) {
			t.Error("Firewall doesn't match role when it should")
		}
	}

	// Test firewall that has no role assigned to it. That shouldn't make it apply
	fw, err = factory.Instantiate(ctx, "testfw")
	util.CheckTestError(t, err)

	if err != nil {
		if fw.MatchesRole(ctx, map[string]string{"role": "no-sso"}) {
			t.Error("Firewall matches role when it shouldn't")
		}

		if fw.MatchesRole(ctx, map[string]string{"role": "default"}) {
			t.Error("Firewall matches role when it shouldn't")
		}
	}
}
