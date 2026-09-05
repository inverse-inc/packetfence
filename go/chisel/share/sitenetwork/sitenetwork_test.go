package sitenetwork

import (
	"context"
	"fmt"
	"net"
	"testing"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/vishvananda/netlink"
)

// fakeNetlink is an in-memory model of the pieces of rtnetlink the
// reconciler touches: links (with addresses) and routes.
type fakeNetlink struct {
	links     map[string]netlink.Link
	addrs     map[string][]netlink.Addr // by link name
	routes    []netlink.Route
	nextIndex int
	writes    []string // log of mutating calls, to assert idempotency
	failAdd   bool
}

func newFake() *fakeNetlink {
	f := &fakeNetlink{links: map[string]netlink.Link{}, addrs: map[string][]netlink.Addr{}, nextIndex: 1}
	f.addDevice("eth0", true)
	return f
}

func (f *fakeNetlink) addDevice(name string, up bool) {
	attrs := netlink.NewLinkAttrs()
	attrs.Name = name
	attrs.Index = f.nextIndex
	f.nextIndex++
	if up {
		attrs.Flags = net.FlagUp
		attrs.OperState = netlink.OperUp
	}
	f.links[name] = &netlink.Device{LinkAttrs: attrs}
}

func (f *fakeNetlink) nameOf(index int) string {
	for name, l := range f.links {
		if l.Attrs().Index == index {
			return name
		}
	}
	return ""
}

func (f *fakeNetlink) LinkList() ([]netlink.Link, error) {
	out := []netlink.Link{}
	for _, l := range f.links {
		out = append(out, l)
	}
	return out, nil
}

func (f *fakeNetlink) LinkByName(name string) (netlink.Link, error) {
	if l, ok := f.links[name]; ok {
		return l, nil
	}
	return nil, fmt.Errorf("Link %s not found", name)
}

func (f *fakeNetlink) LinkAdd(link netlink.Link) error {
	f.writes = append(f.writes, "LinkAdd "+link.Attrs().Name)
	if f.failAdd {
		return fmt.Errorf("operation not permitted")
	}
	vlan, ok := link.(*netlink.Vlan)
	if !ok {
		return fmt.Errorf("fake only supports vlan links")
	}
	attrs := vlan.LinkAttrs
	attrs.Index = f.nextIndex
	f.nextIndex++
	f.links[attrs.Name] = &netlink.Vlan{LinkAttrs: attrs, VlanId: vlan.VlanId}
	return nil
}

func (f *fakeNetlink) LinkDel(link netlink.Link) error {
	f.writes = append(f.writes, "LinkDel "+link.Attrs().Name)
	delete(f.links, link.Attrs().Name)
	delete(f.addrs, link.Attrs().Name)
	return nil
}

func (f *fakeNetlink) LinkSetUp(link netlink.Link) error {
	f.writes = append(f.writes, "LinkSetUp "+link.Attrs().Name)
	link.Attrs().Flags |= net.FlagUp
	return nil
}

func (f *fakeNetlink) LinkSetAlias(link netlink.Link, alias string) error {
	f.writes = append(f.writes, "LinkSetAlias "+link.Attrs().Name)
	link.Attrs().Alias = alias
	return nil
}

func (f *fakeNetlink) AddrList(link netlink.Link, family int) ([]netlink.Addr, error) {
	return f.addrs[link.Attrs().Name], nil
}

func (f *fakeNetlink) AddrReplace(link netlink.Link, addr *netlink.Addr) error {
	f.writes = append(f.writes, fmt.Sprintf("AddrReplace %s %s", link.Attrs().Name, addr.IPNet))
	f.addrs[link.Attrs().Name] = append(f.addrs[link.Attrs().Name], *addr)
	return nil
}

func (f *fakeNetlink) AddrDel(link netlink.Link, addr *netlink.Addr) error {
	f.writes = append(f.writes, fmt.Sprintf("AddrDel %s %s", link.Attrs().Name, addr.IPNet))
	kept := []netlink.Addr{}
	for _, a := range f.addrs[link.Attrs().Name] {
		if a.IPNet.String() != addr.IPNet.String() {
			kept = append(kept, a)
		}
	}
	f.addrs[link.Attrs().Name] = kept
	return nil
}

func (f *fakeNetlink) RouteListFiltered(family int, filter *netlink.Route, mask uint64) ([]netlink.Route, error) {
	out := []netlink.Route{}
	for _, r := range f.routes {
		if mask&netlink.RT_FILTER_PROTOCOL != 0 && r.Protocol != filter.Protocol {
			continue
		}
		out = append(out, r)
	}
	return out, nil
}

func (f *fakeNetlink) RouteReplace(route *netlink.Route) error {
	f.writes = append(f.writes, "RouteReplace "+routeKey(route))
	for i, r := range f.routes {
		if routeKey(&r) == routeKey(route) {
			f.routes[i] = *route
			return nil
		}
	}
	f.routes = append(f.routes, *route)
	return nil
}

func (f *fakeNetlink) RouteDel(route *netlink.Route) error {
	f.writes = append(f.writes, "RouteDel "+routeKey(route))
	kept := []netlink.Route{}
	for _, r := range f.routes {
		if routeKey(&r) != routeKey(route) {
			kept = append(kept, r)
		}
	}
	f.routes = kept
	return nil
}

func desired() Desired {
	return Desired{
		Interfaces: []pfconfigdriver.ConnectorInterface{
			{Parent: "eth0", Vlan: 100, CIDR: "10.10.100.1/24"},
			{Parent: "eth0", Vlan: 101, CIDR: "10.10.101.1/24"},
		},
		Routes: []pfconfigdriver.ConnectorRoute{
			{Destination: "10.20.0.0/16", Gateway: "10.10.100.254", Interface: "eth0.100"},
			{Destination: "192.168.50.0/24", Interface: "eth0.101"},
		},
	}
}

func TestReconcileCreatesAndIsIdempotent(t *testing.T) {
	f := newFake()
	r := NewWithNetlink(f)
	ctx := context.Background()

	st := r.Reconcile(ctx, "v1", desired())
	if st.Errors != 0 {
		t.Fatalf("expected no errors, got %d: %+v", st.Errors, st)
	}
	for _, name := range []string{"eth0.100", "eth0.101"} {
		l, ok := f.links[name]
		if !ok {
			t.Fatalf("%s not created", name)
		}
		vlan := l.(*netlink.Vlan)
		if vlan.Attrs().Alias != LinkAlias {
			t.Errorf("%s alias = %q, want %q", name, vlan.Attrs().Alias, LinkAlias)
		}
		if vlan.Attrs().ParentIndex != f.links["eth0"].Attrs().Index {
			t.Errorf("%s parent index = %d", name, vlan.Attrs().ParentIndex)
		}
		if vlan.Attrs().Flags&net.FlagUp == 0 {
			t.Errorf("%s not up", name)
		}
		if len(f.addrs[name]) != 1 {
			t.Errorf("%s has %d addresses, want 1", name, len(f.addrs[name]))
		}
	}
	if f.links["eth0.100"].(*netlink.Vlan).VlanId != 100 {
		t.Errorf("wrong vlan id")
	}
	if len(f.routes) != 2 {
		t.Fatalf("expected 2 routes, got %d", len(f.routes))
	}
	for _, rt := range f.routes {
		if rt.Protocol != RouteProtocol {
			t.Errorf("route %s protocol = %d, want %d", routeKey(&rt), rt.Protocol, RouteProtocol)
		}
	}
	if f.routes[0].Gw.String() != "10.10.100.254" || f.nameOf(f.routes[0].LinkIndex) != "eth0.100" {
		t.Errorf("first route wrong: %+v", f.routes[0])
	}
	if f.routes[1].Gw != nil || f.nameOf(f.routes[1].LinkIndex) != "eth0.101" {
		t.Errorf("second route wrong: %+v", f.routes[1])
	}

	// Second pass with the same input must not write anything except the
	// RouteReplace calls, which are the idempotent "make sure it is there"
	// primitive and never remove or alter state.
	f.writes = nil
	st = r.Reconcile(ctx, "v1", desired())
	if st.Errors != 0 {
		t.Fatalf("second pass errors: %+v", st)
	}
	for _, w := range f.writes {
		if len(w) < 12 || w[:12] != "RouteReplace" {
			t.Errorf("unexpected write on idempotent pass: %s", w)
		}
	}
}

func TestReconcileRemovesStaleAndKeepsForeign(t *testing.T) {
	f := newFake()
	r := NewWithNetlink(f)
	ctx := context.Background()
	r.Reconcile(ctx, "v1", desired())

	// A VLAN the operator created by hand: no alias. Must be left alone.
	attrs := netlink.NewLinkAttrs()
	attrs.Name = "eth0.200"
	attrs.Index = f.nextIndex
	f.nextIndex++
	attrs.ParentIndex = f.links["eth0"].Attrs().Index
	f.links["eth0.200"] = &netlink.Vlan{LinkAttrs: attrs, VlanId: 200}

	// A static route the operator installed: kernel protocol, must survive.
	_, dst, _ := net.ParseCIDR("172.16.0.0/12")
	f.routes = append(f.routes, netlink.Route{Dst: dst, Gw: net.ParseIP("10.0.0.1").To4(), Protocol: 4})

	// Drop eth0.101 and its route from the desired state.
	d := desired()
	d.Interfaces = d.Interfaces[:1]
	d.Routes = d.Routes[:1]
	st := r.Reconcile(ctx, "v2", d)
	if st.Errors != 0 {
		t.Fatalf("errors: %+v", st)
	}
	if _, ok := f.links["eth0.101"]; ok {
		t.Errorf("stale eth0.101 not removed")
	}
	if _, ok := f.links["eth0.200"]; !ok {
		t.Errorf("foreign eth0.200 was removed")
	}
	if len(st.Removed) != 1 || st.Removed[0] != "eth0.101" {
		t.Errorf("Removed = %v", st.Removed)
	}
	if len(f.routes) != 2 {
		t.Fatalf("expected connector route + operator route, got %d: %+v", len(f.routes), f.routes)
	}
	for _, rt := range f.routes {
		if rt.Dst.String() == "192.168.50.0/24" {
			t.Errorf("stale connector route kept")
		}
	}
}

func TestReconcileReplacesAddressAndRecreatesOnTagChange(t *testing.T) {
	f := newFake()
	r := NewWithNetlink(f)
	ctx := context.Background()
	r.Reconcile(ctx, "v1", desired())

	d := desired()
	d.Interfaces[0].CIDR = "10.10.100.2/24" // new address, same link
	d.Interfaces[1].Vlan = 111              // eth0.111: new link, eth0.101 goes away
	d.Routes[1].Interface = "eth0.111"
	st := r.Reconcile(ctx, "v2", d)
	if st.Errors != 0 {
		t.Fatalf("errors: %+v", st)
	}
	addrs := f.addrs["eth0.100"]
	if len(addrs) != 1 || addrs[0].IPNet.String() != "10.10.100.2/24" {
		t.Errorf("eth0.100 addrs = %v", addrs)
	}
	if _, ok := f.links["eth0.111"]; !ok {
		t.Errorf("eth0.111 not created")
	}
	if _, ok := f.links["eth0.101"]; ok {
		t.Errorf("eth0.101 not removed")
	}
}

func TestReconcileReportsPerItemErrors(t *testing.T) {
	f := newFake()
	r := NewWithNetlink(f)
	ctx := context.Background()

	d := Desired{
		Interfaces: []pfconfigdriver.ConnectorInterface{
			{Parent: "eth9", Vlan: 100, CIDR: "10.10.100.1/24"}, // missing parent
			{Parent: "eth0", Vlan: 101, CIDR: "10.10.101.1/24"}, // fine
			{Parent: "eth0", Vlan: 102, CIDR: "10.10.102.0/24"}, // fine at this layer (form rejects network addr)
		},
		Routes: []pfconfigdriver.ConnectorRoute{
			{Destination: "0.0.0.0/0", Gateway: "10.10.101.254"},    // default route refused
			{Destination: "10.30.0.0/16"},                           // neither gw nor dev
			{Destination: "10.40.0.0/16", Interface: "nonexistent"}, // bad dev
			{Destination: "10.50.0.0/16", Gateway: "10.10.101.254"}, // fine
		},
	}
	st := r.Reconcile(ctx, "v1", d)
	if st.Errors != 4 {
		t.Fatalf("expected 4 errors, got %d: %+v", st.Errors, st)
	}
	if st.Interfaces[0].State != "error" || st.Interfaces[1].State != "up" {
		t.Errorf("interface states: %+v", st.Interfaces)
	}
	if _, ok := f.links["eth0.101"]; !ok {
		t.Errorf("a bad entry blocked a good one")
	}
	if st.Routes[3].State != "applied" || len(f.routes) != 1 {
		t.Errorf("good route not applied: %+v (%d routes)", st.Routes, len(f.routes))
	}
	for i := range 3 {
		if st.Routes[i].State != "error" || st.Routes[i].Error == "" {
			t.Errorf("route %d should be an error: %+v", i, st.Routes[i])
		}
	}
}

func TestReconcileParentDownIsReported(t *testing.T) {
	f := newFake()
	f.addDevice("eth1", false)
	r := NewWithNetlink(f)
	st := r.Reconcile(context.Background(), "v1", Desired{Interfaces: []pfconfigdriver.ConnectorInterface{{Parent: "eth1", Vlan: 5, CIDR: "10.0.5.1/24"}}})
	if st.Errors != 0 {
		t.Fatalf("a down parent is not an error: %+v", st)
	}
	if st.Interfaces[0].State != "down" {
		t.Errorf("state = %s, want down", st.Interfaces[0].State)
	}
}
