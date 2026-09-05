package chclient

import (
	"os"
	"path/filepath"
	"testing"
)

// The HA configuration comes from the env override first, else from the ha
// block of the cached site-network payload, else HA is off.
func TestResolveHAConfig(t *testing.T) {
	dir := t.TempDir()
	orig := siteNetworkCachePath
	siteNetworkCachePath = filepath.Join(dir, "site-network.json")
	t.Cleanup(func() { siteNetworkCachePath = orig })
	t.Setenv("PFCONNECTOR_HA_VIP", "")

	if c := ResolveHAConfig(); c != nil {
		t.Fatalf("no cache, no env: expected nil, got %+v", c)
	}
	os.WriteFile(siteNetworkCachePath, []byte(`{"version":"v1","interfaces":[],"routes":[],"ha":{"vip":"","vrid":"","interface":""}}`), 0o644)
	if c := ResolveHAConfig(); c != nil {
		t.Fatalf("cache without VIP: expected nil, got %+v", c)
	}
	os.WriteFile(siteNetworkCachePath, []byte(`{"version":"v2","ha":{"vip":"10.0.0.250/24","vrid":"51","interface":"ens18"}}`), 0o644)
	c := ResolveHAConfig()
	if c == nil || c.VIP != "10.0.0.250/24" || c.VRID != "51" || c.Interface != "ens18" {
		t.Fatalf("cache with VIP: got %+v", c)
	}
	t.Setenv("PFCONNECTOR_HA_VIP", "10.0.0.251/24")
	t.Setenv("PFCONNECTOR_HA_VRID", "60")
	c = ResolveHAConfig()
	if c == nil || c.VIP != "10.0.0.251/24" || c.VRID != "60" {
		t.Fatalf("env override: got %+v", c)
	}
	if ip, err := ParseVIP(c.VIP); err != nil || ip.String() != "10.0.0.251" {
		t.Fatalf("ParseVIP: %v %v", ip, err)
	}
	os.WriteFile(siteNetworkCachePath, []byte(`not json`), 0o644)
	t.Setenv("PFCONNECTOR_HA_VIP", "")
	if c := ResolveHAConfig(); c != nil {
		t.Fatalf("corrupt cache: expected nil, got %+v", c)
	}
}
