package chserver

import (
	"reflect"
	"testing"

	"github.com/inverse-inc/packetfence/go/chisel/share/settings"
	"github.com/inverse-inc/packetfence/go/pfk8s"
)

func mustRemote(t *testing.T, def string) *settings.Remote {
	r, err := settings.DecodeRemote(def)
	if err != nil {
		t.Fatal(err)
	}
	return r
}

func TestStaticServicePortsRemoval(t *testing.T) {
	ports := []pfk8s.Port{
		{Name: "port-tcp-443"},   // published by the chart, not a static remote
		{Name: "port-udp-30001"}, // closed: removed
		{Name: "port-udp-18122"}, // closed here, still configured elsewhere: kept
		{Name: "port-tcp-30001"}, // closed: removed
		{Name: "port-udp-30000"}, // not closed: kept
	}
	closed := []*settings.Remote{
		mustRemote(t, "30001:192.0.2.53:53/udp"),
		mustRemote(t, "30001:192.0.2.53:53"),
		mustRemote(t, "18122:192.0.2.10:1812/udp"),
	}
	configured := map[string][]string{
		"connector1": {"30000:192.0.2.20:53/udp"},
		"connector2": {"18122:192.0.2.10:1812/udp"},
	}

	got := staticServicePortsRemoval(ports, closed, configured)
	want := []pfk8s.PatchPorts{
		{Op: "test", Path: "/spec/ports/3/name", Value: "port-tcp-30001"},
		{Op: "remove", Path: "/spec/ports/3"},
		{Op: "test", Path: "/spec/ports/1/name", Value: "port-udp-30001"},
		{Op: "remove", Path: "/spec/ports/1"},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("patch:\n got %+v\nwant %+v", got, want)
	}

	if patch := staticServicePortsRemoval(ports, nil, configured); len(patch) != 0 {
		t.Errorf("nothing closed, patch %+v", patch)
	}
}
