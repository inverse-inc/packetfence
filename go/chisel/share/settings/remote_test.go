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
		{"several drops", "80=-,443=-", map[string]string{"80": "-", "443": "-"}},
		{"same target on different protocols", "80/tcp=8080,53/udp=8080", map[string]string{"80/tcp": "8080", "53/udp": "8080"}},
		{"port/proto overrides port", "53=5353,53/udp=-", map[string]string{"53": "5353", "53/udp": "-"}},
		{"same source port and target is an override", "53=5353,53/udp=5353", map[string]string{"53": "5353", "53/udp": "5353"}},
		{"target is a source only for the other protocol", "80/udp=443,443/tcp=8443", map[string]string{"80/udp": "443", "443/tcp": "8443"}},
		{"target is dropped only for the other protocol", "80/tcp=53,53/udp=-", map[string]string{"80/tcp": "53", "53/udp": "-"}},
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
		"443",                   // missing '='
		"abc=8443",              // source not a port
		"70000=80",              // source out of range
		"53/icmp=-",             // unsupported protocol
		"443=abc",               // target not a port
		"443=",                  // empty target
		"443=8443/tcp",          // protocol not allowed on target
		"443=8443,80",           // one bad entry fails the whole map
		"0=8443",                // source port 0
		"443=0",                 // target port 0
		"443=8443,443=-",        // duplicate source
		"80=443,443=80",         // cycle
		"80/tcp=443,443/tcp=80", // cycle with protocols
		"80=443,443/tcp=80",     // cycle on tcp
		"443=443",               // maps onto itself
		"80=443,443=8443",       // chain
		"80=443,443=-",          // chain into a dropped port
		"80=443,443/tcp=8443",   // "80" also covers tcp, which chains into 443/tcp
		"80=8080,443=8080",      // two sources, same target
		"80=8080,443/tcp=8080",  // same target on tcp
		"80=8080,53/udp=8080",   // "80" also covers udp, so 80/udp and 53/udp collide
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
		conflicts   int
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
		{
			name:        "remap onto an existing bind is skipped",
			bindPortMap: map[string]string{"80": "443"},
			expected:    []string{"443/tcp", "53/tcp", "53/udp", "1815/udp"},
			conflicts:   1,
		},
		{
			name:        "collision is checked per protocol",
			bindPortMap: map[string]string{"53": "1815"},
			expected:    []string{"80/tcp", "443/tcp", "1815/tcp", "1815/udp"},
			conflicts:   1,
		},
		{
			name:        "remap onto a port only bound for the other protocol is allowed",
			bindPortMap: map[string]string{"80": "1815"},
			expected:    []string{"1815/tcp", "443/tcp", "53/tcp", "53/udp", "1815/udp"},
		},
		{
			name:        "conflict is checked against original ports, not remapped ones",
			bindPortMap: map[string]string{"443": "8443", "80": "443"},
			expected:    []string{"8443/tcp", "53/tcp", "53/udp", "1815/udp"},
			conflicts:   1,
		},
	}
	for _, test := range tests {
		remapped, conflicts := RemapRemoteBinds(test.bindPortMap, newRemotes())
		if got := ports(remapped); !reflect.DeepEqual(got, test.expected) {
			t.Fatalf("%s: got %v, expected %v", test.name, got, test.expected)
		}
		if len(conflicts) != test.conflicts {
			t.Fatalf("%s: got conflicts %v, expected %d", test.name, conflicts, test.conflicts)
		}
	}
}
