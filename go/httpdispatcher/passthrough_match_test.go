package httpdispatcher

import (
	"net"
	"net/http"
	"net/http/httptest"
	"regexp"
	"testing"
)

func TestHostMatcher(t *testing.T) {
	m := newHostMatcher()
	m.add("crl.geotrust.com")
	m.add("*.example.org")
	m.add("Mixed.Case.NET.")

	for _, test := range []struct {
		host     string
		expected bool
	}{
		{"crl.geotrust.com", true},
		{"CRL.GeoTrust.com", true},
		{"crl.geotrust.com:80", true},
		{"crl.geotrust.com.", true},
		{"crl.geotrust.com.example.net", false},
		{"crl.geotrust.com.example.net:8080", false},
		{"xcrl.geotrust.com", false},
		{"crlxgeotrust.com", false},
		{"www.crl.geotrust.com", false},
		{"example.org", true},
		{"www.example.org", true},
		{"a.b.example.org:8080", true},
		{"badexample.org", false},
		{"example.org.other.net", false},
		{"mixed.case.net", true},
		{"", false},
	} {
		if got := m.match(test.host); got != test.expected {
			t.Errorf("host %q: got %v, expected %v", test.host, got, test.expected)
		}
	}

	var empty *hostMatcher
	if empty.match("crl.geotrust.com") {
		t.Errorf("an empty matcher matches nothing")
	}
}

func TestDetectionRequest(t *testing.T) {
	p := newProxyPassthrough(ctx)
	for _, u := range []string{"http://www.apple.com/library/test/success", "http://captive.apple.com", "http://clients3.google.com/generate_204"} {
		if err := p.addDetectionMechanismsToList(ctx, u); err != nil {
			t.Fatalf("Cannot add %s: %s", u, err)
		}
	}
	p.URIException = regexp.MustCompile("CaptiveNetworkSupport")

	for _, test := range []struct {
		host     string
		path     string
		expected bool
	}{
		{"www.apple.com", "/library/test/success.html", true},
		{"www.apple.com:80", "/library/test/success", true},
		{"captive.apple.com", "/hotspot-detect.html", true},
		{"clients3.google.com", "/generate_204", true},
		{"clients3.google.com", "/other", false},
		{"www.apple.com", "/other", false},
		{"www.apple.com.example.net", "/library/test/success", false},
		{"example.net", "/http://captive.apple.com", false},
		{"example.net", "/CaptiveNetworkSupport", false},
		{"www.apple.com", "/CaptiveNetworkSupport/x", true},
	} {
		if got := p.checkDetectionRequest(ctx, test.host, test.path); got != test.expected {
			t.Errorf("%s%s: got %v, expected %v", test.host, test.path, got, test.expected)
		}
	}
}

func TestProxiedDestination(t *testing.T) {
	for _, test := range []struct {
		ip       string
		expected bool
	}{
		{"93.184.216.34", true},
		{"10.0.0.10", true},
		{"192.168.1.10", true},
		{"2001:db8::10", true},
		{"127.0.0.1", false},
		{"127.10.0.1", false},
		{"::1", false},
		{"0.0.0.0", false},
		{"169.254.169.254", false},
		{"fe80::1", false},
		{"224.0.0.1", false},
		{"100.64.0.1", false},
		{"100.127.255.254", false},
	} {
		if got := isProxiedDestinationAllowed(net.ParseIP(test.ip)); got != test.expected {
			t.Errorf("%s: got %v, expected %v", test.ip, got, test.expected)
		}
	}

	if proxiedDestinationControl("tcp4", "100.64.0.1:8080", nil) == nil {
		t.Errorf("the containers gateway is refused by the dialer")
	}
	if proxiedDestinationControl("tcp4", "93.184.216.34:80", nil) != nil {
		t.Errorf("a public address is allowed by the dialer")
	}
}

func TestReversePassthroughRefusesLocalDestinations(t *testing.T) {
	// A service on the loopback, as the services of the PacketFence server
	listener, err := net.Listen("tcp", "127.0.0.1:80")
	if err == nil {
		defer listener.Close()
		go func() {
			for {
				c, err := listener.Accept()
				if err != nil {
					return
				}
				c.Write([]byte("HTTP/1.0 200 OK\r\n\r\nlocal service"))
				c.Close()
			}
		}()
	}

	var p Proxy
	for _, host := range []string{"localhost", "127.0.0.1", "localhost:8080"} {
		req := httptest.NewRequest("GET", "http://"+host+"/", nil)
		recorder := httptest.NewRecorder()
		p.reversePassthrough(ctx, recorder, req, host)
		if recorder.Code != http.StatusBadGateway {
			t.Errorf("%s: got %d, expected %d", host, recorder.Code, http.StatusBadGateway)
		}
	}
}
