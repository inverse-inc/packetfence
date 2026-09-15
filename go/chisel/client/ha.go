package chclient

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"strings"
)

// HAConfig is the VRRP configuration shared by the hosts of a connector. It
// comes from the admin UI (connectors.conf ha_* fields) through the
// site-network payload and is cached on disk with it, so a host learns it on
// its first connection and a backup, which has no tunnel, reads the cache.
// PFCONNECTOR_HA_VIP in the env file overrides it (host-side setup).
type HAConfig struct {
	VIP       string `json:"vip"`
	VRID      string `json:"vrid"`
	Interface string `json:"interface"`
}

// Enabled reports whether a VIP is configured.
func (c HAConfig) Enabled() bool { return strings.TrimSpace(c.VIP) != "" }

// HAConfigFromEnv returns the host-side override, or nil.
func HAConfigFromEnv() *HAConfig {
	vip := strings.TrimSpace(os.Getenv("PFCONNECTOR_HA_VIP"))
	if vip == "" {
		return nil
	}
	return &HAConfig{VIP: vip, VRID: os.Getenv("PFCONNECTOR_HA_VRID"), Interface: os.Getenv("PFCONNECTOR_HA_INTERFACE")}
}

// HAConfigFromCache reads the HA block of the cached site-network payload
// (siteNetworkCachePath), or nil when there is no cache or no VIP in it.
func HAConfigFromCache() *HAConfig {
	data, err := os.ReadFile(siteNetworkCachePath)
	if err != nil {
		return nil
	}
	var cached struct {
		HA HAConfig `json:"ha"`
	}
	if err := json.Unmarshal(data, &cached); err != nil || !cached.HA.Enabled() {
		return nil
	}
	return &cached.HA
}

// ResolveHAConfig returns the effective HA configuration: the env override,
// else the cache, else nil (HA off or not learnt yet).
func ResolveHAConfig() *HAConfig {
	if c := HAConfigFromEnv(); c != nil {
		return c
	}
	return HAConfigFromCache()
}

// ParseVIP parses the PFCONNECTOR_HA_VIP value, an IPv4 address with or
// without a prefix length (10.0.0.250 or 10.0.0.250/24), and returns the
// address.
func ParseVIP(value string) (net.IP, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil, fmt.Errorf("empty VIP")
	}
	if strings.Contains(value, "/") {
		ip, _, err := net.ParseCIDR(value)
		if err != nil {
			return nil, fmt.Errorf("invalid VIP %q: %w", value, err)
		}
		return ip, nil
	}
	ip := net.ParseIP(value)
	if ip == nil {
		return nil, fmt.Errorf("invalid VIP %q", value)
	}
	return ip, nil
}

// VIPPresent reports whether the given address is currently assigned to one
// of the host's interfaces, i.e. whether this host owns the VRRP virtual IP.
// The container runs with --network=host, so this reads the host namespace.
func VIPPresent(vip net.IP) (bool, error) {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return false, err
	}
	for _, a := range addrs {
		var ip net.IP
		switch v := a.(type) {
		case *net.IPNet:
			ip = v.IP
		case *net.IPAddr:
			ip = v.IP
		}
		if ip != nil && ip.Equal(vip) {
			return true, nil
		}
	}
	return false, nil
}
