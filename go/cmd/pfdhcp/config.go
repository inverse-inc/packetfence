package main

import (
	"context"
	"database/sql"
	"encoding/binary"
	"fmt"
	"math"
	"net"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	cache "github.com/fdurand/go-cache"
	dhcp "github.com/inverse-inc/dhcp4"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/dhcp/pool"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	netadv "github.com/simon/go-netadv"
)

// DHCPHandler struct
type DHCPHandler struct {
	ip            net.IP // Server IP to use
	vip           net.IP
	options       dhcp.Options  // Options to send to DHCP Clients
	start         net.IP        // Start of IP range to distribute
	leaseRange    int           // Number of IPs to distribute (starting from start)
	leaseDuration time.Duration // Lease period
	hwcache       *cache.Cache
	xid           *cache.Cache
	available     pool.Backend // DHCPPool keeps track of the available IPs in the pool
	layer2        bool
	role          string
	ipReserved    string
	ipAssigned    map[string]uint32
	dstIp         string
}

// Interfaces struct
type Interfaces struct {
	intsNet []Interface
}

// Interface struct
type Interface struct {
	Name          string
	intNet        *net.Interface
	network       []Network
	layer2        []*net.IPNet
	Ipv4          net.IP
	Ipv6          net.IP
	InterfaceType string
	relayIP       net.IP
	listenPort    int
}

// Network struct
type Network struct {
	network     net.IPNet
	dhcpHandler *DHCPHandler
	splittednet bool
}

const bootpClient = 68
const bootpServer = 67

func newDHCPConfig() *Interfaces {
	var p Interfaces
	return &p
}

func (d *Interfaces) readConfig(ctx context.Context, MyDB *sql.DB) {
	interfaces := pfconfigdriver.GetType[pfconfigdriver.ListenInts](ctx)
	DHCPinterfaces := pfconfigdriver.GetType[pfconfigdriver.DHCPInts](ctx)
	portal := pfconfigdriver.GetType[pfconfigdriver.PfConfCaptivePortal](ctx)
	general := pfconfigdriver.GetType[pfconfigdriver.PfConfGeneral](ctx)

	var keyConfNet pfconfigdriver.PfconfigKeys
	keyConfNet.PfconfigNS = "config::Network"
	keyConfNet.PfconfigHostnameOverlay = "yes"

	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfNet)

	var intDhcp []string

	for _, vi := range DHCPinterfaces.Element {
		for key, dhcpint := range vi.(map[string]interface{}) {
			if key == "int" {
				intDhcp = append(intDhcp, dhcpint.(string))
			}
		}
	}

	physical := sharedutils.RemoveDuplicates(append(interfaces.Element, intDhcp...))
	if dohOnly() {
		log.LoggerWContext(ctx).Info("PFDHCP_DOH_ONLY is set: serving DHCP over HTTP only, no scope on the local interfaces")
		physical = nil
	}

	wg := &sync.WaitGroup{}
	for _, v := range physical {

		eth, err := net.InterfaceByName(v)

		if err != nil {
			log.LoggerWContext(ctx).Error("Cannot find interface " + v + " on the system due to an error: " + err.Error())
			continue
		} else if eth == nil {
			log.LoggerWContext(ctx).Error("Cannot find interface " + v + " on the system")
			continue
		}
		var backend string

		var ethIf Interface

		ethIf.intNet = eth
		ethIf.Name = eth.Name
		ethIf.InterfaceType = "server"
		ethIf.listenPort = bootpServer

		adresses, _ := eth.Addrs()

		for _, adresse := range adresses {

			var NetIP *net.IPNet
			var IP net.IP
			IP, NetIP, _ = net.ParseCIDR(adresse.String())

			a, b := NetIP.Mask.Size()
			if a == b {
				continue
			}

			if IsIPv6(IP) {
				ethIf.Ipv6 = IP
				continue
			}
			if IsIPv4(IP) {
				ethIf.Ipv4 = IP
			}

			ethIf.layer2 = append(ethIf.layer2, NetIP)
			for _, key := range keyConfNet.Keys {
				var ConfNet pfconfigdriver.RessourseNetworkConf
				ConfNet.PfconfigHashNS = key
				pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)
				if ConfNet.Dhcpd == "disabled" {
					continue
				}

				if (NetIP.Contains(net.ParseIP(ConfNet.DhcpStart)) && NetIP.Contains(net.ParseIP(ConfNet.DhcpEnd))) || NetIP.Contains(net.ParseIP(ConfNet.NextHop)) {
					dhcpStart := net.ParseIP(ConfNet.DhcpStart).To4()
					dhcpEnd := net.ParseIP(ConfNet.DhcpEnd).To4()
					if dhcpStart == nil || dhcpEnd == nil {
						log.LoggerWContext(ctx).Error("Invalid DHCP start or end IP address for network " + key)
						continue
					}
					if int(binary.BigEndian.Uint32(dhcpStart)) > int(binary.BigEndian.Uint32(dhcpEnd)) {
						log.LoggerWContext(ctx).Error("Wrong configuration, check your network " + key)
						continue
					}

					// IP per role
					if sharedutils.IsEnabled(ConfNet.SplitNetwork) {
						var keyConfRoles pfconfigdriver.PfconfigKeys
						keyConfRoles.PfconfigNS = "config::Roles"

						pfconfigdriver.FetchDecodeSocket(ctx, &keyConfRoles)

						// Add the registration role
						keyConfRoles.Keys = append(keyConfRoles.Keys, "registration")

						netsize, _ := NetIP.Mask.Size()

						cidr := math.Ceil(math.Log(float64(len(keyConfRoles.Keys)))/math.Log(2) + float64(netsize))

						smallnet, _ := netadv.SplitNetworks(NetIP, uint(cidr))

						var Roles []string
						var Role string

						Roles = append([]string(nil), keyConfRoles.Keys...)

						for _, subnet := range smallnet {
							var DHCPNet Network
							var DHCPScope *DHCPHandler
							DHCPScope = &DHCPHandler{}
							var NetWork *net.IPNet
							var lastrole bool
							if len(Roles) == 1 {
								lastrole = true
								Role = Roles[0]
							} else {
								Role, Roles = Roles[len(Roles)-1], Roles[:len(Roles)-1]
							}
							DHCPScope.role = Role
							DHCPNet.splittednet = true

							var ip net.IP

							if (Role == "registration") && (ConfNet.RegNetwork != "") {
								IP, NetWork, _ = net.ParseCIDR(ConfNet.RegNetwork)
							} else {
								NetWork = subnet
							}

							ip = []byte(NetWork.IP.To4())

							DHCPNet.network.IP = append([]byte(nil), NetWork.IP...)

							DHCPNet.network.Mask = NetWork.Mask

							// First ip available in the scope (packetfence ip)
							sharedutils.Inc(ip)

							DHCPScope.ip = net.ParseIP(ip.String())

							var seconds int

							if Role == "registration" {
								// lease duration need to be low in registration role
								seconds, _ = strconv.Atoi("30")
								// Use the first ip define in networks.conf
								if ConfNet.RegNetwork != "" {
									sharedutils.Inc(IP)
									ip = append([]byte(nil), IP...)
								} else {
									ip = append([]byte(nil), net.ParseIP(ConfNet.DhcpStart)...)
								}
							} else {
								seconds, _ = strconv.Atoi(ConfNet.DhcpDefaultLeaseTime)
								sharedutils.Inc(ip)
							}
							// First ip available for endpoint
							DHCPScope.start = append([]byte(nil), ip...)
							DHCPScope.leaseDuration = time.Duration(seconds) * time.Second
							var ips net.IP

							for ipe := net.IPv4(NetWork.IP[0], NetWork.IP[1], NetWork.IP[2], NetWork.IP[3]); NetWork.Contains(ipe); sharedutils.Inc(ipe) {
								ips = append([]byte(nil), ipe...)
							}
							// Decrement twice to have the last ip available for the scope
							sharedutils.Dec(ips)

							DHCPScope.leaseRange = dhcp.IPRange(ip, ips)
							// Default value for algorithm
							algorithm := 1
							algorithm, _ = strconv.Atoi(ConfNet.Algorithm)
							if ConfNet.PoolBackend == "" {
								backend = "memory"
							} else {
								backend = ConfNet.PoolBackend
							}
							var dstReplyIp string
							if ConfNet.DhcpReplyIp == "" {
								dstReplyIp = "giaddr"
							} else {
								dstReplyIp = ConfNet.DhcpReplyIp
							}
							DHCPScope.dstIp = dstReplyIp
							// Initialize dhcp pool
							available, _ := pool.Create(ctx, backend, uint64(dhcp.IPRange(ip, ips)), DHCPNet.network.IP.String()+Role, algorithm, StatsdClient, MyDB)

							DHCPScope.available = available

							// Initialize hardware cache
							hwcache := cache.New(time.Duration(seconds)*time.Second, 2*time.Second)

							hwcache.OnEvicted(func(nic string, pool interface{}) {
								go func() {
									idx := uint64(pool.(int))
									_, currentMac, err := DHCPScope.available.GetMACIndex(idx)
									if err != nil {
										return
									}
									// Only release the slot if the pool still has it
									// bound to the evicted MAC. Skip when it has been
									// reassigned (e.g. FakeMac cool-down, static
									// binding, or another MAC took over).
									if currentMac != nic {
										return
									}
									log.LoggerWContext(ctx).Info(nic + " " + dhcp.IPAdd(DHCPScope.start, pool.(int)).String() + " Added back in the pool " + DHCPScope.role + " on index " + strconv.Itoa(pool.(int)))
									DHCPScope.available.FreeIPIndex(idx)
								}()
							})

							DHCPScope.hwcache = hwcache

							xid := cache.New(time.Duration(4)*time.Second, 2*time.Second)

							DHCPScope.xid = xid
							wg.Add(1)
							go func() {
								initiaLease(ctx, DHCPScope, ConfNet, MyDB)
								wg.Done()
							}()
							var options = make(map[dhcp.OptionCode][]byte)

							options[dhcp.OptionSubnetMask] = []byte(DHCPNet.network.Mask)
							options[dhcp.OptionDomainNameServer] = []byte(DHCPScope.ip.To4())
							options[dhcp.OptionRouter] = []byte(DHCPScope.ip.To4())
							options[dhcp.OptionDomainName] = []byte(ConfNet.DomainName)
							if sharedutils.IsEnabled(portal.SecureRedirect) {
								options[dhcp.OptionCaptivePortal] = []byte(detectPortalURL(ConfNet, general))
							}
							DHCPScope.options = options
							if len(ConfNet.NextHop) > 0 {
								DHCPScope.layer2 = false
							} else {
								DHCPScope.layer2 = true
							}
							DHCPNet.dhcpHandler = DHCPScope
							ethIf.network = append(ethIf.network, DHCPNet)

							if lastrole == true {
								break
							}
						}

					} else {
						ethIf.network = append(ethIf.network, buildPlainScope(ctx, key, ConfNet, IP.To4(), VIPIp[eth.Name], MyDB, general, portal, wg))
					}
				}
			}
		}
		wg.Wait()
		d.intsNet = append(d.intsNet, ethIf)

	}

	if connectorIf := buildConnectorInterface(ctx, MyDB, general, portal); connectorIf != nil {
		d.intsNet = append(d.intsNet, *connectorIf)
	}
}

// ConnectorInterfaceName is the name of the synthetic interface that owns the
// DHCP scopes of the pfconnector-remote VLAN interfaces (DHCP-over-HTTPS). It
// has no socket: requests reach it through POST /api/v1/dhcp/message and the
// replies go back in the HTTP response. VIP[ConnectorInterfaceName] is always
// true.
const ConnectorInterfaceName = "connector"

// ConnectorInterfaceType marks the synthetic interface so that listeners,
// pings and anything else touching a real NIC skip it.
const ConnectorInterfaceType = "api"

// dohOnly reports whether pfdhcp must serve exclusively over HTTP
// (PFDHCP_DOH_ONLY=true, the cloud deployment): no scope is built for the
// local interfaces and no UDP listener is started.
func dohOnly() bool {
	switch strings.ToLower(os.Getenv("PFDHCP_DOH_ONLY")) {
	case "1", "true", "yes", "enabled":
		return true
	}
	return false
}

// buildConnectorInterface returns the synthetic interface holding one scope
// per connector VLAN interface with DHCP enabled (connectors.conf), or nil
// when there is none. The scope is derived from the interface: network and
// netmask from its CIDR, server identifier (and default gateway) its address,
// range, lease times, DNS and domain from the dhcp_* fields.
func buildConnectorInterface(ctx context.Context, MyDB *sql.DB, general *pfconfigdriver.PfConfGeneral, portal *pfconfigdriver.PfConfCaptivePortal) *Interface {
	connectors := pfconfigdriver.Connectors{}
	if err := pfconfigdriver.FetchDecodeSocket(ctx, &connectors); err != nil {
		log.LoggerWContext(ctx).Error("Unable to fetch connectors config from pfconfig: " + err.Error())
		return nil
	}
	iface := &Interface{Name: ConnectorInterfaceName, InterfaceType: ConnectorInterfaceType, listenPort: bootpServer}
	wg := &sync.WaitGroup{}
	ids := make([]string, 0, len(connectors.Element))
	for id := range connectors.Element {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	for _, id := range ids {
		for _, ci := range connectors.Element[id].Interfaces {
			if !sharedutils.IsEnabled(ci.Dhcp) {
				continue
			}
			ConfNet, key, scopeIP, err := connectorScopeConf(ci)
			if err != nil {
				log.LoggerWContext(ctx).Error(fmt.Sprintf("connector %s interface %s: DHCP scope skipped: %s", id, ci.Name(), err))
				continue
			}
			log.LoggerWContext(ctx).Info(fmt.Sprintf("DHCP scope %s/%s for connector %s interface %s (range %s-%s, server identifier %s)", key, ConfNet.Netmask, id, ci.Name(), ConfNet.DhcpStart, ConfNet.DhcpEnd, scopeIP))
			if iface.Ipv4 == nil {
				iface.Ipv4 = scopeIP
			}
			iface.network = append(iface.network, buildPlainScope(ctx, key, ConfNet, scopeIP, nil, MyDB, general, portal, wg))
		}
	}
	wg.Wait()
	if len(iface.network) == 0 {
		return nil
	}
	return iface
}

// connectorScopeConf translates a connector VLAN interface into the network
// configuration buildPlainScope expects. Returns the network address (the
// scope key) and the interface address (server identifier).
func connectorScopeConf(ci pfconfigdriver.ConnectorInterface) (pfconfigdriver.RessourseNetworkConf, string, net.IP, error) {
	var ConfNet pfconfigdriver.RessourseNetworkConf
	ip, ipnet, err := net.ParseCIDR(ci.CIDR)
	if err != nil || ip.To4() == nil {
		return ConfNet, "", nil, fmt.Errorf("invalid address %q", ci.CIDR)
	}
	start, end := net.ParseIP(ci.DhcpStart), net.ParseIP(ci.DhcpEnd)
	if start == nil || end == nil || !ipnet.Contains(start) || !ipnet.Contains(end) || dhcp.IPRange(start, end) < 1 {
		return ConfNet, "", nil, fmt.Errorf("invalid range %q-%q for %s", ci.DhcpStart, ci.DhcpEnd, ipnet)
	}
	ConfNet.Type = "other"
	ConfNet.Dhcpd = "enabled"
	ConfNet.Netmask = net.IP(ipnet.Mask).String()
	ConfNet.DhcpStart = start.String()
	ConfNet.DhcpEnd = end.String()
	ConfNet.DhcpDefaultLeaseTime = orDefault(ci.DhcpDefaultLeaseTime, "300")
	ConfNet.DhcpMaxLeaseTime = orDefault(ci.DhcpMaxLeaseTime, "600")
	ConfNet.Dns = ci.Dns
	ConfNet.Gateway = orDefault(ci.Gateway, ip.String())
	ConfNet.DomainName = ci.DomainName
	ConfNet.PoolBackend = orDefault(os.Getenv("PFDHCP_CONNECTOR_POOL_BACKEND"), "memory")
	ConfNet.Algorithm = "1"
	// The relay answers renewals: the client must never talk to the server
	// address directly, so replies always go back through the HTTP path.
	ConfNet.DhcpReplyIp = "source"
	// Keep the interface address out of the pool.
	if dhcp.IPRange(start, ip) >= 1 && dhcp.IPRange(ip, end) >= 1 {
		ConfNet.IpReserved = ip.String()
	}
	return ConfNet, ipnet.IP.String(), ip.To4(), nil
}

func orDefault(v, def string) string {
	if v == "" {
		return def
	}
	return v
}

// buildPlainScope builds the DHCP scope (pool, caches, options) of a network
// that is not split per role, attached to the interface whose address is
// scopeIP. Shared by the real interfaces and the synthetic connector
// interface (see buildConnectorInterface).
func buildPlainScope(ctx context.Context, key string, ConfNet pfconfigdriver.RessourseNetworkConf, scopeIP net.IP, vip net.IP, MyDB *sql.DB, general *pfconfigdriver.PfConfGeneral, portal *pfconfigdriver.PfConfCaptivePortal, wg *sync.WaitGroup) Network {
	var DHCPNet Network
	DHCPScope := &DHCPHandler{}
	DHCPNet.splittednet = false
	DHCPNet.network.IP = net.ParseIP(key)
	DHCPNet.network.Mask = net.IPMask(net.ParseIP(ConfNet.Netmask))
	DHCPScope.ip = scopeIP
	if vip != nil {
		DHCPScope.vip = vip
	}
	DHCPScope.role = "none"
	DHCPScope.start = net.ParseIP(ConfNet.DhcpStart)
	seconds, _ := strconv.Atoi(ConfNet.DhcpDefaultLeaseTime)
	DHCPScope.leaseDuration = time.Duration(seconds) * time.Second
	DHCPScope.leaseRange = dhcp.IPRange(net.ParseIP(ConfNet.DhcpStart), net.ParseIP(ConfNet.DhcpEnd))
	// Default value for algorithm
	algorithm := 1
	algorithm, _ = strconv.Atoi(ConfNet.Algorithm)
	backend := "memory"
	if ConfNet.PoolBackend != "" {
		backend = ConfNet.PoolBackend
	}
	var dstReplyIp string

	if ConfNet.DhcpReplyIp == "" {
		dstReplyIp = "giaddr"
	} else {
		dstReplyIp = ConfNet.DhcpReplyIp
	}
	DHCPScope.dstIp = dstReplyIp
	// Initialize dhcp pool
	available, _ := pool.Create(ctx, backend, uint64(dhcp.IPRange(net.ParseIP(ConfNet.DhcpStart), net.ParseIP(ConfNet.DhcpEnd))), DHCPNet.network.IP.String(), algorithm, StatsdClient, MyDB)

	DHCPScope.available = available

	// Initialize hardware cache
	hwcache := cache.New(time.Duration(seconds)*time.Second, 2*time.Second)

	hwcache.OnEvicted(func(nic string, pool interface{}) {
		go func() {
			idx := uint64(pool.(int))
			_, currentMac, err := DHCPScope.available.GetMACIndex(idx)
			if err != nil {
				return
			}
			// Only release the slot if the pool still has it
			// bound to the evicted MAC. Skip when it has been
			// reassigned (e.g. FakeMac cool-down, static
			// binding, or another MAC took over).
			if currentMac != nic {
				return
			}
			log.LoggerWContext(ctx).Info(nic + " " + dhcp.IPAdd(DHCPScope.start, pool.(int)).String() + " Added back in the pool " + DHCPScope.role + " on index " + strconv.Itoa(pool.(int)))
			DHCPScope.available.FreeIPIndex(idx)
		}()
	})

	DHCPScope.hwcache = hwcache

	xid := cache.New(time.Duration(4)*time.Second, 2*time.Second)

	DHCPScope.xid = xid
	wg.Add(1)
	go func() {
		initiaLease(ctx, DHCPScope, ConfNet, MyDB)
		wg.Done()
	}()

	var options = make(map[dhcp.OptionCode][]byte)

	options[dhcp.OptionSubnetMask] = []byte(net.ParseIP(ConfNet.Netmask).To4())
	options[dhcp.OptionDomainNameServer] = ShuffleDNS(ctx, ConfNet)
	options[dhcp.OptionRouter] = ShuffleGateway(ctx, ConfNet)
	options[dhcp.OptionDomainName] = []byte(ConfNet.DomainName)
	if sharedutils.IsEnabled(portal.SecureRedirect) {
		options[dhcp.OptionCaptivePortal] = []byte(detectPortalURL(ConfNet, general))
	}
	DHCPScope.options = options
	if len(ConfNet.NextHop) > 0 {
		DHCPScope.layer2 = false
	} else {
		DHCPScope.layer2 = true
	}
	DHCPNet.dhcpHandler = DHCPScope
	return DHCPNet
}

func detectPortalURL(ConfNet pfconfigdriver.RessourseNetworkConf, general *pfconfigdriver.PfConfGeneral) string {
	var portalURL string
	if ConfNet.PortalFQDN != "" {
		portalURL = "https://" + ConfNet.PortalFQDN + "/rfc7710"

	} else {
		portalURL = "https://" + general.Hostname + "." + general.Domain + "/rfc7710"
	}
	return portalURL
}
