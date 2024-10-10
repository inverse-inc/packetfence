package firewallsso

import (
	"context"
	"testing"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/util"
)

var ctx = log.LoggerNewContext(context.Background())

var sampleInfo = map[string]string{
	"username": "lzammit",
	"ip":       "1.2.3.4",
	"mac":      "00:11:22:33:44:55",
	"role":     "default",
	"status":   "reg",
}

func TestStart(t *testing.T) {
	mockfw := &MockFW{
		FirewallSSO: FirewallSSO{
			RoleBasedFirewallSSO: RoleBasedFirewallSSO{
				Roles: []string{"default"},
			},
			Networks: []*FirewallSSONetwork{
				&FirewallSSONetwork{
					Cidr: "172.20.0.0/16",
				},
				&FirewallSSONetwork{
					Cidr: "192.168.0.0/24",
				},
			},
		},
	}
	mockfw.init(ctx)

	result, _ := ExecuteStart(ctx, mockfw, map[string]string{"ip": "172.20.0.1", "role": "default", "mac": "00:11:22:33:44:55", "username": "lzammit", "status": "reg"}, 0)
	if !result {
		t.Error("SSO didn't succeed with valid parameters")
	}

	// invalid role, invalid IP
	result, _ = ExecuteStart(ctx, mockfw, map[string]string{"ip": "1.2.3.4", "role": "no-sso-on-that", "mac": "00:11:22:33:44:55", "username": "lzammit", "status": "reg"}, 0)
	if result {
		t.Error("SSO succeeded with invalid parameters")
	}

	// valid role, invalid IP
	result, _ = ExecuteStart(ctx, mockfw, map[string]string{"ip": "1.2.3.4", "role": "default", "mac": "00:11:22:33:44:55", "username": "lzammit", "status": "reg"}, 0)
	if result {
		t.Error("SSO succeeded with invalid parameters")
	}

	mockfw = &MockFW{
		FirewallSSO: FirewallSSO{
			RoleBasedFirewallSSO: RoleBasedFirewallSSO{
				Roles: []string{"default", "gaming"},
			},
			Networks: []*FirewallSSONetwork{},
		},
	}
	mockfw.init(ctx)

	result, _ = ExecuteStart(ctx, mockfw, map[string]string{"ip": "172.20.0.1", "role": "gaming", "mac": "00:11:22:33:44:55", "username": "lzammit", "status": "reg"}, 0)

	if !result {
		t.Error("SSO failed with valid parameters")
	}

	// invalid role, IP doesn't matter
	result, _ = ExecuteStart(ctx, mockfw, map[string]string{"ip": "1.2.3.4", "role": "no-sso-on-that", "mac": "00:11:22:33:44:55", "username": "lzammit", "status": "reg"}, 0)

	if result {
		t.Error("SSO succeeded with invalid parameters")
	}

}

func TestStop(t *testing.T) {
	mockfw := &MockFW{
		FirewallSSO: FirewallSSO{
			RoleBasedFirewallSSO: RoleBasedFirewallSSO{
				Roles: []string{"default"},
			},
			Networks: []*FirewallSSONetwork{
				&FirewallSSONetwork{
					Cidr: "172.20.0.0/16",
				},
				&FirewallSSONetwork{
					Cidr: "192.168.0.0/24",
				},
			},
		},
	}
	mockfw.init(ctx)

	// invalid role, invalid IP, so shouldn't do it
	result, _ := ExecuteStop(ctx, mockfw, map[string]string{"ip": "1.2.3.4", "role": "no-sso-on-that", "mac": "00:11:22:33:44:55", "username": "lzammit", "status": "reg"})

	if result {
		t.Error("SSO succeeded with invalid parameters")
	}

	// invalid role, valid IP, so should do it because role doesn't matter in stop
	result, _ = ExecuteStop(ctx, mockfw, map[string]string{"ip": "172.20.0.1", "role": "no-sso-on-that", "mac": "00:11:22:33:44:55", "username": "lzammit", "status": "reg"})

	if !result {
		t.Error("SSO failed with invalid parameters")
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
		if fw.MatchesNetwork(ctx, map[string]string{"ip": "192.168.0.28.vidange"}) {
			t.Error("Firewall matches network with an invalid IP")
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
		if !fw.MatchesNetwork(ctx, map[string]string{"ip": "192.168.0.28.vidange"}) {
			t.Error("Invalid IP address should pass MatchesNetwork if the FW doesn't define any network")
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

func TestGetSourceIp(t *testing.T) {
	factory := NewFactory(ctx)

	// Test firewall that has 1 or more role assigned to it
	fw, err := factory.Instantiate(ctx, "testfw2")
	util.CheckTestError(t, err)

	expected := "10.0.0.13"
	if fw.getSourceIp(ctx).String() != expected {
		t.Errorf("Wrong source IP for firewall. Got %s instead of %s", fw.getSourceIp(ctx).String(), expected)
	}
}

func TestShouldCacheUpdates(t *testing.T) {
	factory := NewFactory(ctx)

	//Test with a firewall that has it enabled
	fw, err := factory.Instantiate(ctx, "testfw")
	util.CheckTestError(t, err)

	if !fw.ShouldCacheUpdates(ctx) {
		t.Error("ShouldCacheUpdates reports false although its enabled")
	}

	fw, err = factory.Instantiate(ctx, "testfw2")
	util.CheckTestError(t, err)

	if fw.ShouldCacheUpdates(ctx) {
		t.Error("ShouldCacheUpdates reports true when value is undefined. Should actually report false.")
	}

	fw, err = factory.Instantiate(ctx, "paloalto.com")
	util.CheckTestError(t, err)

	if fw.ShouldCacheUpdates(ctx) {
		t.Error("ShouldCacheUpdates reports true when value is 0. Should actually report false.")
	}
}

func TestGetCacheTimeout(t *testing.T) {
	factory := NewFactory(ctx)

	fw, err := factory.Instantiate(ctx, "testfw")
	util.CheckTestError(t, err)

	expected := 0
	if fw.GetCacheTimeout(ctx) != expected {
		t.Errorf("Cache timeout is invalid. Expected %d and got %d", expected, fw.GetCacheTimeout(ctx))
	}

	fw, err = factory.Instantiate(ctx, "testfw2")
	util.CheckTestError(t, err)

	expected = 0
	if fw.GetCacheTimeout(ctx) != expected {
		t.Errorf("Cache timeout is invalid. Expected %d and got %d", expected, fw.GetCacheTimeout(ctx))
	}

	fw, err = factory.Instantiate(ctx, "paloalto.com")
	util.CheckTestError(t, err)

	expected = 3600
	if fw.GetCacheTimeout(ctx) != expected {
		t.Errorf("Cache timeout is invalid. Expected %d and got %d", expected, fw.GetCacheTimeout(ctx))
	}

}

func TestFormatUsername(t *testing.T) {
	factory := NewFactory(ctx)

	// Firewall that wants to format it $realm\$username
	fw, err := factory.Instantiate(ctx, "testfw")
	util.CheckTestError(t, err)

	// Test it while having all the infos
	username := fw.FormatUsername(ctx, map[string]string{
		"username":          "bobby@example.com",
		"stripped_username": "bobby",
		"realm":             "example.com",
	})

	if username != "example.com\\bobby" {
		t.Errorf("Unexpected username out of the formatting %s", username)
	}

	// Test missing the realm
	username = fw.FormatUsername(ctx, map[string]string{
		"username":          "bobby@example.com",
		"stripped_username": "bobby",
	})

	if username != "pouet\\bobby" {
		t.Errorf("Unexpected username out of the formatting %s", username)
	}

	// Firewall that wants the format $pf_username
	fw, err = factory.Instantiate(ctx, "testfw2")
	util.CheckTestError(t, err)

	// Test it while having all the infos
	username = fw.FormatUsername(ctx, map[string]string{
		"username":          "bobby@example.com",
		"stripped_username": "bobby",
		"realm":             "example.com",
	})

	if username != "bobby@example.com" {
		t.Errorf("Unexpected username out of the formatting %s", username)
	}
}
