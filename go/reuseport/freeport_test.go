package reuseport

import (
	"context"
	"testing"
)

func TestFreeTcpPort(t *testing.T) {
	l1, _, err := FreeTcpPort()
	if err != nil {
		t.Fatalf("%s", err.Error())
	}

	defer l1.Close()
	l2, err := ReusePortListenConfig.Listen(context.Background(), "tcp", l1.Addr().String())
	if err != nil {
		t.Fatalf("%s", err.Error())
	}

	if l2.Addr().String() != l1.Addr().String() {
		t.Fatalf("Not the same address")
	}
}

func TestFreeUdpPort(t *testing.T) {
	l1, _, err := FreeUdpPort()
	if err != nil {
		t.Fatalf("%s", err.Error())
	}

	defer l1.Close()
	l2, err := ReusePortListenConfig.ListenPacket(context.Background(), "udp", l1.LocalAddr().String())
	if err != nil {
		t.Fatalf("%s", err.Error())
	}

	if l2.LocalAddr().String() != l1.LocalAddr().String() {
		t.Fatalf("Not the same address")
	}
}
