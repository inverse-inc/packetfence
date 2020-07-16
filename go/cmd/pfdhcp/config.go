package main

import (
	"encoding/binary"
	"math"
	"net"
	"strconv"
	"sync"
	"time"

	cache "github.com/fdurand/go-cache"
	"github.com/inverse-inc/packetfence/go/dhcp/pool"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	dhcp "github.com/krolaw/dhcp4"
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

func (d *Interfaces) readConfig() {

	var interfaces pfconfigdriver.ListenInts
	pfconfigdriver.FetchDecodeSocket(ctx, &interfaces)

	var DHCPinterfaces pfconfigdriver.DHCPInts
	pfconfigdriver.FetchDecodeSocket(ctx, &DHCPinterfaces)

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

	wg := &sync.WaitGroup{}
	for _, v := range sharedutils.RemoveDuplicates(append(interfaces.Element, intDhcp...)) {

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
					if int(binary.BigEndian.Uint32(net.ParseIP(ConfNet.DhcpStart).To4())) > int(binary.BigEndian.Uint32(net.ParseIP(ConfNet.DhcpEnd).To4())) {
						log.LoggerWContext(ctx).Error("Wrong configuration, check your network " + key)
						continue
					}

					// IP per role
					if ConfNet.SplitNetwork == "enabled" {
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
							// Initialize dhcp pool
							available, _ := pool.Create(ctx, backend, uint64(dhcp.IPRange(ip, ips)), DHCPNet.network.IP.String()+Role, algorithm, StatsdClient, MySQLdatabase)

							DHCPScope.available = available

							// Initialize hardware cache
							hwcache := cache.New(time.Duration(seconds)*time.Second, 2*time.Second)

							hwcache.OnEvicted(func(nic string, pool interface{}) {
								go func() {
									log.LoggerWContext(ctx).Info(nic + " " + dhcp.IPAdd(DHCPScope.start, pool.(int)).String() + " Added back in the pool " + DHCPScope.role + " on index " + strconv.Itoa(pool.(int)))
									DHCPScope.available.FreeIPIndex(uint64(pool.(int)))
								}()
							})

							DHCPScope.hwcache = hwcache

							xid := cache.New(time.Duration(4)*time.Second, 2*time.Second)

							DHCPScope.xid = xid
							wg.Add(1)
							go func() {
								initiaLease(DHCPScope, ConfNet)
								wg.Done()
							}()
							var options = make(map[dhcp.OptionCode][]byte)

							options[dhcp.OptionSubnetMask] = []byte(DHCPNet.network.Mask)
							options[dhcp.OptionDomainNameServer] = []byte(DHCPScope.ip.To4())
							options[dhcp.OptionRouter] = []byte(DHCPScope.ip.To4())
							options[dhcp.OptionDomainName] = []byte(ConfNet.DomainName)
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
						var DHCPNet Network
						var DHCPScope *DHCPHandler
						DHCPScope = &DHCPHandler{}
						DHCPNet.splittednet = false
						DHCPNet.network.IP = net.ParseIP(key)
						DHCPNet.network.Mask = net.IPMask(net.ParseIP(ConfNet.Netmask))
						DHCPScope.ip = IP.To4()
						if _, found := VIPIp[eth.Name]; found {
							DHCPScope.vip = VIPIp[eth.Name]
						}
						DHCPScope.role = "none"
						DHCPScope.start = net.ParseIP(ConfNet.DhcpStart)
						seconds, _ := strconv.Atoi(ConfNet.DhcpDefaultLeaseTime)
						DHCPScope.leaseDuration = time.Duration(seconds) * time.Second
						DHCPScope.leaseRange = dhcp.IPRange(net.ParseIP(ConfNet.DhcpStart), net.ParseIP(ConfNet.DhcpEnd))
						// Default value for algorithm
						algorithm := 1
						algorithm, _ = strconv.Atoi(ConfNet.Algorithm)
						if ConfNet.PoolBackend == "" {
							backend = "memory"
						} else {
							backend = ConfNet.PoolBackend
						}
						// Initialize dhcp pool
						available, _ := pool.Create(ctx, backend, uint64(dhcp.IPRange(net.ParseIP(ConfNet.DhcpStart), net.ParseIP(ConfNet.DhcpEnd))), DHCPNet.network.IP.String(), algorithm, StatsdClient, MySQLdatabase)

						DHCPScope.available = available

						// Initialize hardware cache
						hwcache := cache.New(time.Duration(seconds)*time.Second, 2*time.Second)

						hwcache.OnEvicted(func(nic string, pool interface{}) {
							go func() {
								log.LoggerWContext(ctx).Info(nic + " " + dhcp.IPAdd(DHCPScope.start, pool.(int)).String() + " Added back in the pool " + DHCPScope.role + " on index " + strconv.Itoa(pool.(int)))
								DHCPScope.available.FreeIPIndex(uint64(pool.(int)))
							}()
						})

						DHCPScope.hwcache = hwcache

						xid := cache.New(time.Duration(4)*time.Second, 2*time.Second)

						DHCPScope.xid = xid
						wg.Add(1)
						go func() {
							initiaLease(DHCPScope, ConfNet)
							wg.Done()
						}()

						var options = make(map[dhcp.OptionCode][]byte)

						options[dhcp.OptionSubnetMask] = []byte(net.ParseIP(ConfNet.Netmask).To4())
						options[dhcp.OptionDomainNameServer] = ShuffleDNS(ConfNet)
						options[dhcp.OptionRouter] = ShuffleGateway(ConfNet)
						options[dhcp.OptionDomainName] = []byte(ConfNet.DomainName)
						DHCPScope.options = options
						if len(ConfNet.NextHop) > 0 {
							DHCPScope.layer2 = false
						} else {
							DHCPScope.layer2 = true
						}
						DHCPNet.dhcpHandler = DHCPScope

						ethIf.network = append(ethIf.network, DHCPNet)
					}
				}
			}
		}
		wg.Wait()
		d.intsNet = append(d.intsNet, ethIf)

	}
}
