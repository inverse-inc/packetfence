package httpdispatcher

import (
	"fmt"
	"net"
	"net/url"
	"strings"
	"syscall"
)

// normHost returns the host name of a Host header or URL host: without the
// port, in lower case and without the trailing dot
func normHost(host string) string {
	host = strings.TrimSpace(host)
	if h, _, err := net.SplitHostPort(host); err == nil {
		host = h
	}
	host = strings.TrimPrefix(strings.TrimSuffix(host, "]"), "[")
	return strings.TrimSuffix(strings.ToLower(host), ".")
}

// hostMatcher matches host names: exact names, and the domains given as
// *.example.com that match example.com and its subdomains
type hostMatcher struct {
	exact    map[string]bool
	suffixes []string
}

func newHostMatcher() *hostMatcher {
	return &hostMatcher{exact: make(map[string]bool)}
}

// add a host name or a *.domain to the matcher
func (m *hostMatcher) add(entry string) {
	entry = strings.TrimSpace(entry)
	if strings.HasPrefix(entry, "*.") {
		domain := normHost(strings.TrimPrefix(entry, "*."))
		if domain != "" {
			m.exact[domain] = true
			m.suffixes = append(m.suffixes, "."+domain)
		}
		return
	}
	if host := normHost(entry); host != "" {
		m.exact[host] = true
	}
}

// match returns whether the host (with or without port) is one of the names or in one of the domains
func (m *hostMatcher) match(host string) bool {
	if m == nil {
		return false
	}
	host = normHost(host)
	if host == "" {
		return false
	}
	if m.exact[host] {
		return true
	}
	for _, suffix := range m.suffixes {
		if strings.HasSuffix(host, suffix) {
			return true
		}
	}
	return false
}

// detectionMechanism is a captive portal detection URL: its host and the
// start of its path
type detectionMechanism struct {
	host       string
	pathPrefix string
}

// newDetectionMechanism parses a detection mechanism URL (e.g.
// http://www.apple.com/library/test/success)
func newDetectionMechanism(rawURL string) (detectionMechanism, error) {
	u, err := url.Parse(strings.TrimSpace(rawURL))
	if err != nil {
		return detectionMechanism{}, err
	}
	host := normHost(u.Host)
	if host == "" {
		return detectionMechanism{}, fmt.Errorf("no host name in %q", rawURL)
	}
	return detectionMechanism{host: host, pathPrefix: u.Path}, nil
}

// match returns whether a request (host and path) is for this detection mechanism
func (d detectionMechanism) match(host, path string) bool {
	return normHost(host) == d.host && strings.HasPrefix(path, d.pathPrefix)
}

// containersNetwork is the network of the containers of PacketFence
var _, containersNetwork, _ = net.ParseCIDR("100.64.0.0/10")

// isProxiedDestinationAllowed returns whether a passthrough request can be
// proxied to the IP address: not a loopback, unspecified, link-local or
// multicast address, nor an address of the containers network
func isProxiedDestinationAllowed(ip net.IP) bool {
	if ip == nil {
		return false
	}
	if ip.IsLoopback() || ip.IsUnspecified() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() || ip.IsInterfaceLocalMulticast() || ip.IsMulticast() {
		return false
	}
	return !containersNetwork.Contains(ip)
}

// proxiedDestinationControl is the Control of the dialer of the passthrough
// requests: it refuses the connections to the addresses that are not allowed,
// after the name resolution
func proxiedDestinationControl(network, address string, c syscall.RawConn) error {
	host, _, err := net.SplitHostPort(address)
	if err != nil {
		return err
	}
	if !isProxiedDestinationAllowed(net.ParseIP(host)) {
		return fmt.Errorf("passthrough destination %s is not allowed", host)
	}
	return nil
}
