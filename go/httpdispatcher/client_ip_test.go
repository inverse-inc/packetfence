package httpdispatcher

import "testing"

func TestClientIP(t *testing.T) {
	trusted := trustedProxies("192.0.2.10, 192.0.2.11")

	for _, test := range []struct {
		name         string
		remoteAddr   string
		forwardedFor []string
		expected     string
	}{
		{"local proxy, one hop", "100.64.0.1:51000", []string{"10.0.0.5"}, "10.0.0.5"},
		{"loopback proxy, one hop", "127.0.0.1:51000", []string{"10.0.0.5"}, "10.0.0.5"},
		{"local proxy, two header lines", "100.64.0.1:51000", []string{"10.0.0.99", "10.0.0.5"}, "10.0.0.5"},
		{"local proxy, comma separated", "100.64.0.1:51000", []string{"10.0.0.99, 10.0.0.5"}, "10.0.0.5"},
		{"load balancer hop is skipped", "100.64.0.1:51000", []string{"10.0.0.5", "192.0.2.10"}, "10.0.0.5"},
		{"load balancers hops are skipped", "100.64.0.1:51000", []string{"10.0.0.5, 192.0.2.11, 192.0.2.10"}, "10.0.0.5"},
		{"local proxy without header", "100.64.0.1:51000", nil, "0.0.0.0"},
		{"local proxy with trusted hops only", "100.64.0.1:51000", []string{"127.0.0.1"}, "0.0.0.0"},
		{"untrusted peer, header ignored", "10.0.0.7:51000", []string{"10.0.0.5"}, "10.0.0.7"},
		{"untrusted peer without header", "10.0.0.7:51000", nil, "10.0.0.7"},
		{"remote address without port", "10.0.0.7", []string{"10.0.0.5"}, "10.0.0.7"},
		{"IPv6 local proxy", "[::1]:51000", []string{"2001:db8::5"}, "2001:db8::5"},
		{"IPv6 untrusted peer", "[2001:db8::7]:51000", []string{"2001:db8::5"}, "2001:db8::7"},
	} {
		if got := clientIP(test.remoteAddr, test.forwardedFor, trusted); got != test.expected {
			t.Errorf("%s: got %q, expected %q", test.name, got, test.expected)
		}
	}
}
