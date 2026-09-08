// Package sitenetwork reconciles the host's VLAN interfaces, interface
// addresses and static routes with the desired state pushed by the
// pfconnector server for a connector (see the connector's "Networking" tab in
// the admin UI and docs/design/pfconnector-remote-site-networking.md).
//
// The pfconnector-remote container runs with --network=host and NET_ADMIN, so
// netlink calls made here act on the host network namespace.
//
// Two kinds of interface entries: a VLAN interface (Vlan > 0) the connector
// creates on top of a parent link, and a plain interface (Vlan == 0), an
// existing link of the host such as a second NIC, that the connector only
// addresses. The host's main interface (the one holding the default route,
// through which the tunnel runs) is never addressed.
//
// Ownership rules, so we never touch what the operator configured by hand:
//   - every link we create carries the alias LinkAlias; only aliased links are
//     ever deleted or re-addressed;
//   - every address we put on a plain interface carries the label
//     AddressLabel(name); only labelled addresses are ever removed from a link
//     we did not create;
//   - every route we install carries the routing protocol RouteProtocol; only
//     routes with that protocol are ever deleted.
package sitenetwork

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"net"
	"os"
	"sort"
	"strings"
	"sync"
	"syscall"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/vishvananda/netlink"
)

// LinkAlias marks the VLAN links created by the connector (IFLA_IFALIAS).
const LinkAlias = "pf-connector"

// RouteProtocol marks the routes installed by the connector (RTPROT). Values
// above RTPROT_STATIC (4) and outside the range used by routing daemons are
// free for local use; 201 is not registered in /etc/iproute2/rt_protos.
const RouteProtocol = 201

// addressLabelSuffix is appended to the link name to label the addresses the
// connector assigns on plain (not connector-created) interfaces.
const addressLabelSuffix = ":pf"

// AddressLabel is the IFA_LABEL the connector puts on the addresses it
// assigns on the plain interface name ("<name>:pf", the classic alias form
// that ip(8) and keepalived accept). Empty when the label would not fit in
// IFNAMSIZ; such an address is still assigned but cannot be told apart from
// the operator's, so it is never removed automatically.
func AddressLabel(name string) string {
	label := name + addressLabelSuffix
	if len(label) > syscall.IFNAMSIZ-1 {
		return ""
	}
	return label
}

// DefaultRouteInterface returns the name of the interface holding the IPv4
// default route (/proc/net/route, destination 0.0.0.0), or "" when none. That
// is the host's main interface: the one the connector reaches PacketFence
// through.
func DefaultRouteInterface() string {
	file, err := os.Open("/proc/net/route")
	if err != nil {
		return ""
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		fields := strings.Fields(scanner.Text())
		if len(fields) >= 2 && fields[1] == "00000000" {
			return fields[0]
		}
	}
	return ""
}

// IsContainerInterface reports whether name is an interface of the container
// runtime on the connector host (Docker's default bridge, the bridges of its
// user-defined networks and the container-side veth pairs). They are not
// site-facing: never addressed, and hidden from the admin UI choices.
func IsContainerInterface(name string) bool {
	return name == "docker0" || strings.HasPrefix(name, "br-") || strings.HasPrefix(name, "veth")
}

// Desired is the state to converge to.
type Desired struct {
	Interfaces []pfconfigdriver.ConnectorInterface
	Routes     []pfconfigdriver.ConnectorRoute
}

// InterfaceStatus is the observed state of one desired interface entry. Vlan
// is 0 for a plain interface (an existing link the connector only addresses).
type InterfaceStatus struct {
	Name    string `json:"name"`
	Parent  string `json:"parent"`
	Vlan    int    `json:"vlan"`
	CIDR    string `json:"cidr"`
	State   string `json:"state"` // up, down, error
	Error   string `json:"error,omitempty"`
	Created bool   `json:"created"`
}

// RouteStatus is the observed state of one desired static route.
type RouteStatus struct {
	Destination string `json:"destination"`
	Gateway     string `json:"gateway,omitempty"`
	Interface   string `json:"interface,omitempty"`
	State       string `json:"state"` // applied, error
	Error       string `json:"error,omitempty"`
}

// Status is the result of one reconcile pass.
type Status struct {
	Version    string            `json:"version"`
	Interfaces []InterfaceStatus `json:"interfaces"`
	Routes     []RouteStatus     `json:"routes"`
	Removed    []string          `json:"removed,omitempty"` // links we deleted this pass
	Errors     int               `json:"errors"`
}

// Netlink is the subset of the netlink API the reconciler uses. It exists so
// the reconcile logic can be unit tested without NET_ADMIN.
type Netlink interface {
	LinkList() ([]netlink.Link, error)
	LinkByName(name string) (netlink.Link, error)
	LinkAdd(link netlink.Link) error
	LinkDel(link netlink.Link) error
	LinkSetUp(link netlink.Link) error
	LinkSetAlias(link netlink.Link, alias string) error
	AddrList(link netlink.Link, family int) ([]netlink.Addr, error)
	AddrReplace(link netlink.Link, addr *netlink.Addr) error
	AddrDel(link netlink.Link, addr *netlink.Addr) error
	RouteListFiltered(family int, filter *netlink.Route, mask uint64) ([]netlink.Route, error)
	RouteAdd(route *netlink.Route) error
	RouteReplace(route *netlink.Route) error
	RouteDel(route *netlink.Route) error
}

type realNetlink struct{}

func (realNetlink) LinkList() ([]netlink.Link, error)            { return netlink.LinkList() }
func (realNetlink) LinkByName(name string) (netlink.Link, error) { return netlink.LinkByName(name) }
func (realNetlink) LinkAdd(link netlink.Link) error              { return netlink.LinkAdd(link) }
func (realNetlink) LinkDel(link netlink.Link) error              { return netlink.LinkDel(link) }
func (realNetlink) LinkSetUp(link netlink.Link) error            { return netlink.LinkSetUp(link) }
func (realNetlink) LinkSetAlias(link netlink.Link, alias string) error {
	return netlink.LinkSetAlias(link, alias)
}
func (realNetlink) AddrList(link netlink.Link, family int) ([]netlink.Addr, error) {
	return netlink.AddrList(link, family)
}
func (realNetlink) AddrReplace(link netlink.Link, addr *netlink.Addr) error {
	return netlink.AddrReplace(link, addr)
}
func (realNetlink) AddrDel(link netlink.Link, addr *netlink.Addr) error {
	return netlink.AddrDel(link, addr)
}
func (realNetlink) RouteListFiltered(family int, filter *netlink.Route, mask uint64) ([]netlink.Route, error) {
	return netlink.RouteListFiltered(family, filter, mask)
}
func (realNetlink) RouteAdd(route *netlink.Route) error     { return netlink.RouteAdd(route) }
func (realNetlink) RouteReplace(route *netlink.Route) error { return netlink.RouteReplace(route) }
func (realNetlink) RouteDel(route *netlink.Route) error     { return netlink.RouteDel(route) }

// Reconciler converges the host with a Desired state.
type Reconciler struct {
	nl Netlink
	// MainInterface names the host's main interface, which plain interface
	// entries may never address. Defaults to DefaultRouteInterface.
	MainInterface func() string
}

// New returns a Reconciler backed by the real netlink socket.
func New() *Reconciler {
	return &Reconciler{nl: realNetlink{}, MainInterface: DefaultRouteInterface}
}

// NewWithNetlink returns a Reconciler backed by the given Netlink (tests).
func NewWithNetlink(nl Netlink) *Reconciler {
	return &Reconciler{nl: nl, MainInterface: DefaultRouteInterface}
}

// Reconcile applies desired to the host. It is idempotent: running it twice
// with the same input performs no netlink writes the second time. Failures are
// per item and never abort the pass; they are reported in the returned Status.
func (r *Reconciler) Reconcile(ctx context.Context, version string, desired Desired) Status {
	status := Status{Version: version, Interfaces: []InterfaceStatus{}, Routes: []RouteStatus{}}

	wanted := map[string]bool{}
	plainAddrs := map[string]*netlink.Addr{} // link name -> address we want on a plain interface
	for _, iface := range desired.Interfaces {
		wanted[iface.Name()] = true
		var st InterfaceStatus
		if iface.IsVlan() {
			st = r.reconcileInterface(ctx, iface)
		} else {
			var addr *netlink.Addr
			st, addr = r.reconcilePlainInterface(ctx, iface)
			if addr != nil {
				plainAddrs[iface.Name()] = addr
			}
		}
		if st.State == "error" {
			status.Errors++
		}
		status.Interfaces = append(status.Interfaces, st)
	}

	// Remove the labelled addresses we put on plain interfaces that are no
	// longer desired.
	status.Errors += r.cleanupPlainAddresses(ctx, plainAddrs)

	// Remove the VLAN links we created that are no longer desired.
	for _, name := range r.ownedLinks(ctx) {
		if wanted[name] {
			continue
		}
		link, err := r.nl.LinkByName(name)
		if err != nil {
			continue
		}
		if err := r.nl.LinkDel(link); err != nil {
			log.LoggerWContext(ctx).Error(fmt.Sprintf("site-network: unable to delete stale VLAN interface %s: %s", name, err))
			status.Errors++
			continue
		}
		log.LoggerWContext(ctx).Info(fmt.Sprintf("site-network: deleted VLAN interface %s", name))
		status.Removed = append(status.Removed, name)
	}

	status.Routes, status.Errors = r.reconcileRoutes(ctx, desired.Routes, status.Errors)
	return status
}

// reconcileInterface makes one VLAN link exist, carry exactly the desired
// IPv4 address (among the addresses we manage) and be up.
func (r *Reconciler) reconcileInterface(ctx context.Context, iface pfconfigdriver.ConnectorInterface) InterfaceStatus {
	name := iface.Name()
	st := InterfaceStatus{Name: name, Parent: iface.Parent, Vlan: iface.Vlan, CIDR: iface.CIDR, State: "error"}
	logger := log.LoggerWContext(ctx)

	if len(name) > syscall.IFNAMSIZ-1 {
		st.Error = fmt.Sprintf("interface name %q is longer than %d characters", name, syscall.IFNAMSIZ-1)
		return st
	}
	addr, err := netlink.ParseAddr(iface.CIDR)
	if err != nil || addr.IP.To4() == nil {
		st.Error = fmt.Sprintf("invalid IPv4 address %q", iface.CIDR)
		return st
	}

	parent, err := r.nl.LinkByName(iface.Parent)
	if err != nil {
		st.Error = fmt.Sprintf("parent interface %s not found: %s", iface.Parent, err)
		return st
	}

	link, err := r.nl.LinkByName(name)
	switch {
	case err == nil:
		vlan, isVlan := link.(*netlink.Vlan)
		if !isVlan {
			st.Error = fmt.Sprintf("%s exists but is not a VLAN interface", name)
			return st
		}
		if link.Attrs().Alias != LinkAlias {
			st.Error = fmt.Sprintf("%s exists but was not created by the connector (alias %q); leaving it alone", name, link.Attrs().Alias)
			return st
		}
		if vlan.VlanId != iface.Vlan || vlan.Attrs().ParentIndex != parent.Attrs().Index {
			// Wrong tag or parent: recreate. The name is the identity.
			if err := r.nl.LinkDel(link); err != nil {
				st.Error = fmt.Sprintf("unable to delete %s for re-creation: %s", name, err)
				return st
			}
			link = nil
		}
	case isNotFound(err):
		link = nil
	default:
		st.Error = fmt.Sprintf("unable to look up %s: %s", name, err)
		return st
	}

	if link == nil {
		vlan := &netlink.Vlan{
			LinkAttrs: netlink.LinkAttrs{Name: name, ParentIndex: parent.Attrs().Index, Alias: LinkAlias},
			VlanId:    iface.Vlan,
		}
		if err := r.nl.LinkAdd(vlan); err != nil {
			st.Error = fmt.Sprintf("unable to create VLAN interface %s: %s", name, err)
			return st
		}
		// LinkAdd does not reliably set the alias on every kernel; enforce it.
		created, err := r.nl.LinkByName(name)
		if err != nil {
			st.Error = fmt.Sprintf("created %s but cannot look it up: %s", name, err)
			return st
		}
		if created.Attrs().Alias != LinkAlias {
			if err := r.nl.LinkSetAlias(created, LinkAlias); err != nil {
				st.Error = fmt.Sprintf("unable to tag %s as connector managed: %s", name, err)
				_ = r.nl.LinkDel(created)
				return st
			}
		}
		logger.Info(fmt.Sprintf("site-network: created VLAN interface %s (parent %s, vlan %d)", name, iface.Parent, iface.Vlan))
		link = created
		st.Created = true
	}

	// Addresses: exactly the desired IPv4 address. Other IPv4 addresses on a
	// link we own were put there by an earlier config; drop them.
	addrs, err := r.nl.AddrList(link, netlink.FAMILY_V4)
	if err != nil {
		st.Error = fmt.Sprintf("unable to list addresses of %s: %s", name, err)
		return st
	}
	have := false
	for _, a := range addrs {
		if a.IPNet != nil && a.IP.Equal(addr.IP) && maskEqual(a.Mask, addr.Mask) {
			have = true
			continue
		}
		if err := r.nl.AddrDel(link, &netlink.Addr{IPNet: a.IPNet}); err != nil {
			logger.Warn(fmt.Sprintf("site-network: unable to remove stale address %s from %s: %s", a.IPNet, name, err))
		} else {
			logger.Info(fmt.Sprintf("site-network: removed address %s from %s", a.IPNet, name))
		}
	}
	if !have {
		if err := r.nl.AddrReplace(link, addr); err != nil {
			st.Error = fmt.Sprintf("unable to assign %s to %s: %s", iface.CIDR, name, err)
			return st
		}
		logger.Info(fmt.Sprintf("site-network: assigned %s to %s", iface.CIDR, name))
	}

	if link.Attrs().Flags&net.FlagUp == 0 {
		if err := r.nl.LinkSetUp(link); err != nil {
			st.Error = fmt.Sprintf("unable to bring %s up: %s", name, err)
			return st
		}
	}

	st.State = "up"
	if parent.Attrs().OperState == netlink.OperDown || parent.Attrs().Flags&net.FlagUp == 0 {
		st.State = "down"
		st.Error = fmt.Sprintf("parent interface %s is down", iface.Parent)
	}
	return st
}

// reconcilePlainInterface puts the desired IPv4 address, labelled as ours, on
// an existing link of the host and brings the link up. The link is never
// created or deleted, other addresses on it are never touched, and the host's
// main interface (default route, tunnel), loopback, container and
// connector-created links are refused. Returns the address it wants on the
// link (nil when refused) so the caller can clean up stale labelled ones.
func (r *Reconciler) reconcilePlainInterface(ctx context.Context, iface pfconfigdriver.ConnectorInterface) (InterfaceStatus, *netlink.Addr) {
	name := iface.Name()
	st := InterfaceStatus{Name: name, Parent: iface.Parent, CIDR: iface.CIDR, State: "error"}
	logger := log.LoggerWContext(ctx)

	if name == "" || len(name) > syscall.IFNAMSIZ-1 {
		st.Error = fmt.Sprintf("invalid interface name %q", name)
		return st, nil
	}
	addr, err := netlink.ParseAddr(iface.CIDR)
	if err != nil || addr.IP.To4() == nil {
		st.Error = fmt.Sprintf("invalid IPv4 address %q", iface.CIDR)
		return st, nil
	}
	addr.Label = AddressLabel(name)

	main := ""
	if r.MainInterface != nil {
		main = r.MainInterface()
	}
	if main != "" && name == main {
		st.Error = fmt.Sprintf("%s is the main interface of the host (default route); the connector does not change its configuration", name)
		return st, nil
	}
	if IsContainerInterface(name) {
		st.Error = fmt.Sprintf("%s belongs to the container runtime; not configuring it", name)
		return st, nil
	}

	link, err := r.nl.LinkByName(name)
	switch {
	case isNotFound(err):
		st.Error = fmt.Sprintf("interface %s not found on the host", name)
		return st, nil
	case err != nil:
		st.Error = fmt.Sprintf("unable to look up %s: %s", name, err)
		return st, nil
	}
	if link.Attrs().Flags&net.FlagLoopback != 0 {
		st.Error = fmt.Sprintf("%s is the loopback interface", name)
		return st, nil
	}
	if link.Attrs().Alias == LinkAlias {
		st.Error = fmt.Sprintf("%s is a VLAN interface created by the connector; configure it as a VLAN interface", name)
		return st, nil
	}

	addrs, err := r.nl.AddrList(link, netlink.FAMILY_V4)
	if err != nil {
		st.Error = fmt.Sprintf("unable to list addresses of %s: %s", name, err)
		return st, addr
	}
	have := false
	for _, a := range addrs {
		if a.IPNet != nil && a.IP.Equal(addr.IP) && maskEqual(a.Mask, addr.Mask) {
			have = true
			continue
		}
		// A previous address of ours on this link (label match) is replaced;
		// anything else on the link is the operator's and stays.
		if addr.Label != "" && a.Label == addr.Label {
			if err := r.nl.AddrDel(link, &netlink.Addr{IPNet: a.IPNet}); err != nil {
				logger.Warn(fmt.Sprintf("site-network: unable to remove stale address %s from %s: %s", a.IPNet, name, err))
			} else {
				logger.Info(fmt.Sprintf("site-network: removed address %s from %s", a.IPNet, name))
			}
		}
	}
	if !have {
		if err := r.nl.AddrReplace(link, addr); err != nil {
			st.Error = fmt.Sprintf("unable to assign %s to %s: %s", iface.CIDR, name, err)
			return st, addr
		}
		if addr.Label == "" {
			logger.Warn(fmt.Sprintf("site-network: assigned %s to %s without a label (name too long): it will not be removed automatically when unconfigured", iface.CIDR, name))
		} else {
			logger.Info(fmt.Sprintf("site-network: assigned %s to %s", iface.CIDR, name))
		}
	}

	if link.Attrs().Flags&net.FlagUp == 0 {
		if err := r.nl.LinkSetUp(link); err != nil {
			st.Error = fmt.Sprintf("unable to bring %s up: %s", name, err)
			return st, addr
		}
		logger.Info(fmt.Sprintf("site-network: brought %s up", name))
		// The operational state read before the link was up is stale.
		if fresh, err := r.nl.LinkByName(name); err == nil {
			link = fresh
		}
	}

	st.State = "up"
	if link.Attrs().OperState == netlink.OperDown {
		st.State = "down"
		st.Error = fmt.Sprintf("%s has no carrier", name)
	}
	return st, addr
}

// cleanupPlainAddresses removes, from every link the connector did not
// create, the IPv4 addresses labelled as ours that are not the one wanted on
// that link. Returns the number of failures.
func (r *Reconciler) cleanupPlainAddresses(ctx context.Context, wanted map[string]*netlink.Addr) int {
	logger := log.LoggerWContext(ctx)
	links, err := r.nl.LinkList()
	if err != nil {
		logger.Error(fmt.Sprintf("site-network: unable to list links: %s", err))
		return 1
	}
	failures := 0
	for _, link := range links {
		name := link.Attrs().Name
		if link.Attrs().Alias == LinkAlias {
			continue // connector-created VLAN links are handled by reconcileInterface
		}
		label := AddressLabel(name)
		if label == "" {
			continue
		}
		addrs, err := r.nl.AddrList(link, netlink.FAMILY_V4)
		if err != nil {
			continue
		}
		want := wanted[name]
		for _, a := range addrs {
			if a.Label != label || a.IPNet == nil {
				continue
			}
			if want != nil && a.IP.Equal(want.IP) && maskEqual(a.Mask, want.Mask) {
				continue
			}
			if err := r.nl.AddrDel(link, &netlink.Addr{IPNet: a.IPNet}); err != nil {
				logger.Error(fmt.Sprintf("site-network: unable to remove stale address %s from %s: %s", a.IPNet, name, err))
				failures++
				continue
			}
			logger.Info(fmt.Sprintf("site-network: removed address %s from %s (no longer configured)", a.IPNet, name))
		}
	}
	return failures
}

// ownedLinks returns the names of the VLAN links tagged with LinkAlias.
func (r *Reconciler) ownedLinks(ctx context.Context) []string {
	links, err := r.nl.LinkList()
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("site-network: unable to list links: %s", err))
		return nil
	}
	names := []string{}
	for _, l := range links {
		if _, isVlan := l.(*netlink.Vlan); isVlan && l.Attrs().Alias == LinkAlias {
			names = append(names, l.Attrs().Name)
		}
	}
	sort.Strings(names)
	return names
}

// reconcileRoutes installs the desired routes (all tagged RouteProtocol) and
// removes the tagged routes that are no longer desired.
func (r *Reconciler) reconcileRoutes(ctx context.Context, desired []pfconfigdriver.ConnectorRoute, errCount int) ([]RouteStatus, int) {
	logger := log.LoggerWContext(ctx)
	statuses := []RouteStatus{}
	wanted := []*netlink.Route{}

	for _, d := range desired {
		st := RouteStatus{Destination: d.Destination, Gateway: d.Gateway, Interface: d.Interface, State: "error"}
		route, err := r.buildRoute(d)
		if err != nil {
			st.Error = err.Error()
			statuses = append(statuses, st)
			errCount++
			continue
		}
		wanted = append(wanted, route)
		if err := r.installRoute(route); err != nil {
			st.Error = fmt.Sprintf("unable to install route: %s", err)
			statuses = append(statuses, st)
			errCount++
			continue
		}
		st.State = "applied"
		statuses = append(statuses, st)
	}

	filter := &netlink.Route{Protocol: RouteProtocol}
	existing, err := r.nl.RouteListFiltered(netlink.FAMILY_V4, filter, netlink.RT_FILTER_PROTOCOL)
	if err != nil {
		logger.Error(fmt.Sprintf("site-network: unable to list connector routes: %s", err))
		return statuses, errCount + 1
	}
	for i := range existing {
		route := existing[i]
		keep := false
		for _, w := range wanted {
			if routeMatches(w, &route) {
				keep = true
				break
			}
		}
		if keep {
			continue
		}
		if err := r.nl.RouteDel(&route); err != nil {
			logger.Error(fmt.Sprintf("site-network: unable to delete stale route %s: %s", routeKey(&route), err))
			errCount++
			continue
		}
		logger.Info(fmt.Sprintf("site-network: deleted route %s", routeKey(&route)))
	}
	return statuses, errCount
}

// installRoute adds a connector route, or updates the connector's own route
// for that destination. A replace keyed on the destination alone would take
// over a foreign route (an operator's static route, the kernel's connected
// route of the VLAN) and the next reconcile would then delete it as stale: a
// destination already routed by anything but the connector is an error and
// is left untouched.
func (r *Reconciler) installRoute(route *netlink.Route) error {
	err := r.nl.RouteAdd(route)
	if err == nil {
		return nil
	}
	if !errors.Is(err, syscall.EEXIST) && !errors.Is(err, os.ErrExist) {
		return err
	}
	existing, lerr := r.nl.RouteListFiltered(netlink.FAMILY_V4, &netlink.Route{Dst: route.Dst, Table: route.Table}, netlink.RT_FILTER_DST|netlink.RT_FILTER_TABLE)
	if lerr != nil {
		return fmt.Errorf("route exists and cannot be inspected: %w", lerr)
	}
	for i := range existing {
		if !ipNetEqual(existing[i].Dst, route.Dst) {
			continue
		}
		if existing[i].Protocol != RouteProtocol {
			return fmt.Errorf("destination already routed outside the connector configuration (protocol %d), not touching it", existing[i].Protocol)
		}
		return r.nl.RouteReplace(route)
	}
	return err
}

func ipNetEqual(a, b *net.IPNet) bool {
	if a == nil || b == nil {
		return a == b
	}
	return a.String() == b.String()
}

// buildRoute turns a configured route into a netlink route tagged with
// RouteProtocol. The interface, when named, must exist; the gateway, when set,
// must be an IPv4 address.
func (r *Reconciler) buildRoute(d pfconfigdriver.ConnectorRoute) (*netlink.Route, error) {
	_, dst, err := net.ParseCIDR(d.Destination)
	if err != nil || dst.IP.To4() == nil {
		return nil, fmt.Errorf("invalid destination %q", d.Destination)
	}
	if ones, _ := dst.Mask.Size(); ones == 0 {
		return nil, errors.New("the default route cannot be managed by the connector")
	}
	route := &netlink.Route{Dst: dst, Protocol: RouteProtocol}
	if d.Gateway != "" {
		gw := net.ParseIP(d.Gateway)
		if gw == nil || gw.To4() == nil {
			return nil, fmt.Errorf("invalid gateway %q", d.Gateway)
		}
		route.Gw = gw.To4()
	}
	if d.Interface != "" {
		link, err := r.nl.LinkByName(d.Interface)
		if err != nil {
			return nil, fmt.Errorf("interface %s not found: %s", d.Interface, err)
		}
		route.LinkIndex = link.Attrs().Index
	}
	if route.Gw == nil && route.LinkIndex == 0 {
		return nil, errors.New("a route needs a gateway, an interface, or both")
	}
	return route, nil
}

// routeMatches reports whether an installed route is the one we wanted. The
// kernel resolves the output device of a gateway route we install without
// one, so the installed route carries a LinkIndex the desired route lacks:
// only compare the link when the configuration named an interface. Comparing
// keys blindly made the reconciler delete the route it had just installed.
func routeMatches(wanted, installed *netlink.Route) bool {
	if (wanted.Dst == nil) != (installed.Dst == nil) {
		return false
	}
	if wanted.Dst != nil && wanted.Dst.String() != installed.Dst.String() {
		return false
	}
	if !wanted.Gw.Equal(installed.Gw) {
		return false
	}
	return wanted.LinkIndex == 0 || wanted.LinkIndex == installed.LinkIndex
}

// routeKey identifies a route by destination, gateway and link, which is what
// the kernel uses to tell two routes to the same prefix apart.
func routeKey(route *netlink.Route) string {
	dst := "default"
	if route.Dst != nil {
		dst = route.Dst.String()
	}
	gw := ""
	if route.Gw != nil {
		gw = route.Gw.String()
	}
	return fmt.Sprintf("%s via %s dev %d", dst, gw, route.LinkIndex)
}

func maskEqual(a, b net.IPMask) bool {
	if a == nil || b == nil {
		return a == nil && b == nil
	}
	ao, ab := a.Size()
	bo, bb := b.Size()
	return ao == bo && ab == bb
}

func isNotFound(err error) bool {
	if err == nil {
		return false
	}
	if _, ok := errors.AsType[netlink.LinkNotFoundError](err); ok {
		return true
	}
	return strings.Contains(err.Error(), "not found")
}

// LinkOwnership reports what the connector owns on the host link name: whether
// the link itself was created by the connector (alias LinkAlias; every IPv4
// address on such a link is the connector's) and, otherwise, which IPv4
// addresses carry the connector's label (AddressLabel). Used by the
// connector's system info so the admin UI can tell the operator's
// configuration from the connector's. Errors yield false and no addresses.
func LinkOwnership(name string) (managedLink bool, managedAddrs []string) {
	link, err := netlink.LinkByName(name)
	if err != nil {
		return false, nil
	}
	managedLink = link.Attrs().Alias == LinkAlias
	addrs, err := netlink.AddrList(link, netlink.FAMILY_V4)
	if err != nil {
		return managedLink, nil
	}
	label := AddressLabel(name)
	for _, a := range addrs {
		if a.IPNet == nil {
			continue
		}
		if managedLink || (label != "" && a.Label == label) {
			managedAddrs = append(managedAddrs, a.IPNet.String())
		}
	}
	return managedLink, managedAddrs
}

// lastStatus is the result of the most recent reconcile pass, exposed to the
// connector's local API (/api/v1/system/info) for the admin UI status panel.
var (
	lastStatusMu sync.RWMutex
	lastStatus   *Status
)

// SetLastStatus records the result of a reconcile pass.
func SetLastStatus(s Status) {
	lastStatusMu.Lock()
	defer lastStatusMu.Unlock()
	copied := s
	lastStatus = &copied
}

// LastStatus returns the most recent reconcile result, or nil when no pass
// has run yet.
func LastStatus() *Status {
	lastStatusMu.RLock()
	defer lastStatusMu.RUnlock()
	return lastStatus
}
