package settings

import (
	"reflect"
	"strings"
	"testing"
)

func testString(t *testing.T, name, got, expected string) {
	if got != expected {
		t.Fatalf("%s got %s : expected %s", name, got, expected)
	}
}

func TestL4Proto(t *testing.T) {
	tests := []struct{ l4proto, head, proto, handler string }{
		{
			l4proto: "1813/udp",
			head:    "1813",
			proto:   "udp",
			handler: "raw",
		},
		{
			l4proto: "1813/udp|radius",
			head:    "1813",
			proto:   "udp",
			handler: "radius",
		},
	}

	for _, test := range tests {
		head, proto, handler := L4Proto(test.l4proto)
		testString(t, "head", head, test.head)
		testString(t, "proto", proto, test.proto)
		testString(t, "handler", handler, test.handler)
	}
}

func TestLocalTcp(t *testing.T) {
	remote, err := DecodeRemote("R:0:1813/tcp")
	if err != nil {
		t.Fatalf("%s", err.Error())
	}

	if remote.LocalPort == "0" {
		t.Fatalf("The local port was not resolved")
	}

	if remote.ReusedTcpListener == nil {
		t.Fatalf("TCPListener not saved")
	}
}

func TestLocalUdp(t *testing.T) {
	remote, err := DecodeRemote("R:0:1813/udp")
	if err != nil {
		t.Fatalf("%s", err.Error())
	}

	if remote.LocalPort == "0" {
		t.Fatalf("The local port was not resolved")
	}

	if remote.ReusedUdpConn == nil {
		t.Fatalf("UdpConn not saved")
	}
}

func TestValidateRemappedRemoteBinds(t *testing.T) {
	valid := []struct {
		name     string
		input    string
		expected map[string]string
	}{
		{"empty", "", map[string]string{}},
		{"remap", "443=8443", map[string]string{"443": "8443"}},
		{"drop", "80=-", map[string]string{"80": "-"}},
		{"proto suffix", "53/udp=5353,53/tcp=-", map[string]string{"53/udp": "5353", "53/tcp": "-"}},
		{"whitespace and empty entries", " 443=8443 , ,80=- ", map[string]string{"443": "8443", "80": "-"}},
	}
	for _, test := range valid {
		got, err := ValidateRemappedRemoteBinds(strings.Split(test.input, ","))
		if err != nil {
			t.Fatalf("%s: unexpected error: %s", test.name, err)
		}
		if !reflect.DeepEqual(got, test.expected) {
			t.Fatalf("%s: got %v, expected %v", test.name, got, test.expected)
		}
	}

	invalid := []string{
		"443",          // missing '='
		"abc=8443",     // source not a port
		"70000=80",     // source out of range
		"53/icmp=-",    // unsupported protocol
		"443=abc",      // target not a port
		"443=",         // empty target
		"443=8443/tcp", // protocol not allowed on target
		"443=8443,80",  // one bad entry fails the whole map
	}
	for _, input := range invalid {
		if _, err := ValidateRemappedRemoteBinds(strings.Split(input, ",")); err == nil {
			t.Fatalf("%q: expected an error", input)
		}
	}
}

func TestRemapRemoteBinds(t *testing.T) {
	newRemotes := func() []*Remote {
		return []*Remote{
			{LocalPort: "80", LocalProto: "tcp"},
			{LocalPort: "443", LocalProto: "tcp"},
			{LocalPort: "53", LocalProto: "tcp"},
			{LocalPort: "53", LocalProto: "udp"},
			{LocalPort: "1815", LocalProto: "udp"},
		}
	}
	ports := func(remotes []*Remote) []string {
		out := []string{}
		for _, r := range remotes {
			out = append(out, r.LocalPort+"/"+r.LocalProto)
		}
		return out
	}

	tests := []struct {
		name        string
		bindPortMap map[string]string
		expected    []string
	}{
		{
			name:        "nil map leaves remotes unchanged",
			bindPortMap: nil,
			expected:    []string{"80/tcp", "443/tcp", "53/tcp", "53/udp", "1815/udp"},
		},
		{
			name:        "remap and drop by port",
			bindPortMap: map[string]string{"443": "8443", "80": "-"},
			expected:    []string{"8443/tcp", "53/tcp", "53/udp", "1815/udp"},
		},
		{
			name:        "port without proto applies to tcp and udp",
			bindPortMap: map[string]string{"53": "5353"},
			expected:    []string{"80/tcp", "443/tcp", "5353/tcp", "5353/udp", "1815/udp"},
		},
		{
			name:        "proto suffix only matches that protocol",
			bindPortMap: map[string]string{"53/udp": "-"},
			expected:    []string{"80/tcp", "443/tcp", "53/tcp", "1815/udp"},
		},
		{
			name:        "port/proto rule takes precedence over port rule",
			bindPortMap: map[string]string{"53": "-", "53/tcp": "5353"},
			expected:    []string{"80/tcp", "443/tcp", "5353/tcp", "1815/udp"},
		},
		{
			name:        "everything dropped",
			bindPortMap: map[string]string{"80": "-", "443": "-", "53": "-", "1815": "-"},
			expected:    []string{},
		},
	}
	for _, test := range tests {
		got := ports(RemapRemoteBinds(test.bindPortMap, newRemotes()))
		if !reflect.DeepEqual(got, test.expected) {
			t.Fatalf("%s: got %v, expected %v", test.name, got, test.expected)
		}
	}
}
