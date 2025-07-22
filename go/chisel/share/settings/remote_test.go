package settings

import (
	"testing"
)

func testString(t *testing.T, name, got, expected string) {
	if got != expected {
		t.Fatalf("%s got %s : expected %s", name, got, expected)
	}
}

func testArrayString(t *testing.T, name string, got []string, expected []string) {

	if len(got) != len(expected) {
		t.Fatalf("%s got %v : expected %v", name, got, expected)
		return
	}

	if len(got) == 0 && len(expected) == 0 {
		return
	}
	if len(got) == 0 && len(expected) > 0 {
		t.Fatalf("%s got %v : expected %v", name, got, expected)
		return
	}

	for i, v := range got {
		if i >= len(expected) {
			t.Fatalf("%s got %s at index %d : expected %s", name,
				v, i, expected)
			return
		}
		if expected[i] == "" {
			t.Fatalf("%s expected empty string at index %d", name, i)
			return
		}
		if v == "" {
			t.Fatalf("%s got empty string at index %d", name, i)
			return
		}
		if v != expected[i] {
			t.Fatalf("%s got %s at index %d : expected %s", name,
				v, i, expected[i])
			return
		}
	}
}

func TestL4Proto(t *testing.T) {
	tests := []struct {
		l4proto, head, handler string
		proto                  []string
	}{
		{
			l4proto: "1813/udp",
			head:    "1813",
			proto:   []string{"udp"},
			handler: "raw",
		},
		{
			l4proto: "1813/udp|radius",
			head:    "1813",
			proto:   []string{"udp"},
			handler: "radius",
		},
	}

	for _, test := range tests {
		head, proto, handler := L4Proto(test.l4proto)
		testString(t, "head", head, test.head)
		testArrayString(t, "proto", proto, test.proto)

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
