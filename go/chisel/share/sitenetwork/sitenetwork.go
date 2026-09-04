// Package sitenetwork reconciles the host's VLAN interfaces, addresses and
// static routes with the desired state pushed by the pfconnector server for a
// connector (see the connector's "Networking" tab in the admin UI and
// docs/design/pfconnector-remote-site-networking.md).
//
// The pfconnector-remote container runs with --network=host and NET_ADMIN, so
// netlink calls made here act on the host network namespace.
//
// Ownership rules, so we never touch what the operator configured by hand:
//   - every link we create carries the alias LinkAlias; only aliased links are
//     ever deleted or re-addressed;
//   - every route we install carries the routing protocol RouteProtocol; only
//     routes with that protocol are ever deleted.
package sitenetwork

import (
	"context"
	"errors"
	"fmt"
	"net"
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

// Desired is the state to converge to.
type Desired struct {
	Interfaces []pfconfigdriver.ConnectorInterface
	Routes     []pfconfigdriver.ConnectorRoute
}

// InterfaceStatus is the observed state of one desired VLAN interface.
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
func (realNetlink) RouteReplace(route *netlink.Route) error { return netlink.RouteReplace(route) }
func (realNetlink) RouteDel(route *netlink.Route) error     { return netlink.RouteDel(route) }

// Reconciler converges the host with a Desired state.
type Reconciler struct {
	nl Netlink
}

// New returns a Reconciler backed by the real netlink socket.
func New() *Reconciler {
	return &Reconciler{nl: realNetlink{}}
}

// NewWithNetlink returns a Reconciler backed by the given Netlink (tests).
func NewWithNetlink(nl Netlink) *Reconciler {
	return &Reconciler{nl: nl}
}

// Reconcile applies desired to the host. It is idempotent: running it twice
// with the same input performs no netlink writes the second time. Failures are
// per item and never abort the pass; they are reported in the returned Status.
func (r *Reconciler) Reconcile(ctx context.Context, version string, desired Desired) Status {
	status := Status{Version: version, Interfaces: []InterfaceStatus{}, Routes: []RouteStatus{}}

	wanted := map[string]bool{}
	for _, iface := range desired.Interfaces {
		wanted[iface.Name()] = true
		st := r.reconcileInterface(ctx, iface)
		if st.State == "error" {
			status.Errors++
		}
		status.Interfaces = append(status.Interfaces, st)
	}

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
	wanted := map[string]*netlink.Route{}

	for _, d := range desired {
		st := RouteStatus{Destination: d.Destination, Gateway: d.Gateway, Interface: d.Interface, State: "error"}
		route, err := r.buildRoute(d)
		if err != nil {
			st.Error = err.Error()
			statuses = append(statuses, st)
			errCount++
			continue
		}
		wanted[routeKey(route)] = route
		if err := r.nl.RouteReplace(route); err != nil {
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
		if _, keep := wanted[routeKey(&route)]; keep {
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
