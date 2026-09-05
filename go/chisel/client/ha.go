package chclient

import (
	"fmt"
	"net"
	"strings"
)

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
