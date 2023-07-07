package settings

import (
	"testing"
)

func testString(t *testing.T, name, got, expected string) {
	if got != expected {
		t.Fatalf("%s got %s : expected %s", name, got, expected)
	}
}

func TestDecodeRemote(t *testing.T) {
	remote, err := DecodeRemote("R:0:389")
	_ = err
	testString(t, "LocalPort", remote.LocalPort, "0")
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
