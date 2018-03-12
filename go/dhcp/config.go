package main

import (
	"math"
	"net"
	"strconv"
	"time"

	"github.com/RoaringBitmap/roaring"

	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	dhcp "github.com/krolaw/dhcp4"
	cache "github.com/patrickmn/go-cache"
	netadv "github.com/simon/go-netadv"
)

type DHCPHandler struct {
	ip            net.IP // Server IP to use
	vip           net.IP
	options       dhcp.Options  // Options to send to DHCP Clients
	start         net.IP        // Start of IP range to distribute
	leaseRange    int           // Number of IPs to distribute (starting from start)
	leaseDuration time.Duration // Lease period
	hwcache       *cache.Cache
	xid           *cache.Cache
	available     *roaring.Bitmap // RoaringBitmap to keep track of available IP addresses
	layer2        bool
	role          string
}

type Interfaces struct {
	intsNet []Interface
}

type Interface struct {
	Name    string
	intNet  *net.Interface
	network []Network
	layer2  []*net.IPNet
	Ipv4    net.IP
	Ipv6    net.IP
}

type Network struct {
	network     net.IPNet
	dhcpHandler DHCPHandler
	splittednet bool
}

func newDHCPConfig() *Interfaces {
	var p Interfaces
	return &p
}

// readDBConfig read pfconfig database configuration
func readDBConfig() pfconfigdriver.PfConfDatabase {
	var sections pfconfigdriver.PfConfDatabase

	pfconfigdriver.FetchDecodeSocket(ctx, &sections)
	return sections
}

func (d *Interfaces) readConfig() {

	var interfaces pfconfigdriver.ListenInts
	pfconfigdriver.FetchDecodeSocket(ctx, &interfaces)

	var keyConfNet pfconfigdriver.PfconfigKeys
	keyConfNet.PfconfigNS = "config::Network"

	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfNet)

	for _, v := range interfaces.Element {

		eth, err := net.InterfaceByName(v)

		if err != nil {
			continue
		}

		var ethIf Interface

		ethIf.intNet = eth
		ethIf.Name = eth.Name

		adresses, _ := eth.Addrs()
		for _, adresse := range adresses {

			var NetIP *net.IPNet
			var IP net.IP
			IP, NetIP, _ = net.ParseCIDR(adresse.String())

			a, b := NetIP.Mask.Size()
			if a == b {
				continue
			}

			if IP.To16() != nil {
				ethIf.Ipv6 = IP
			}
			if IP.To4() != nil {
				ethIf.Ipv4 = IP
			}
			ethIf.layer2 = append(ethIf.layer2, NetIP)

			for _, key := range keyConfNet.Keys {
				var ConfNet pfconfigdriver.RessourseNetworkConf
				ConfNet.PfconfigHashNS = key

				pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)

				if (NetIP.Contains(net.ParseIP(ConfNet.DhcpStart)) && NetIP.Contains(net.ParseIP(ConfNet.DhcpEnd))) || NetIP.Contains(net.ParseIP(ConfNet.NextHop)) {

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
							var DHCPScope DHCPHandler
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

							// Initialize roaring bitmap
							available := roaring.New()

							available.AddRange(0, uint64(dhcp.IPRange(ip, ips)))

							DHCPScope.available = available

							// Initialize hardware cache
							hwcache := cache.New(time.Duration(seconds)*time.Second, 10*time.Second)

							hwcache.OnEvicted(func(nic string, pool interface{}) {
								log.LoggerWContext(ctx).Info(nic + " " + dhcp.IPAdd(DHCPScope.start, pool.(int)).String() + " Added back in the pool " + DHCPScope.role + " on index " + strconv.Itoa(pool.(int)))
								DHCPScope.available.Add(uint32(pool.(int)))
							})

							DHCPScope.hwcache = hwcache

							xid := cache.New(time.Duration(4)*time.Second, 2*time.Second)

							DHCPScope.xid = xid

							initiaLease(&DHCPScope)
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
						var DHCPScope DHCPHandler
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

						// Initialize roaring bitmap
						available := roaring.New()
						available.AddRange(0, uint64(dhcp.IPRange(net.ParseIP(ConfNet.DhcpStart), net.ParseIP(ConfNet.DhcpEnd))))
						DHCPScope.available = available

						// Initialize hardware cache
						hwcache := cache.New(time.Duration(seconds)*time.Second, 10*time.Second)

						hwcache.OnEvicted(func(nic string, pool interface{}) {
							log.LoggerWContext(ctx).Info(nic + " " + dhcp.IPAdd(DHCPScope.start, pool.(int)).String() + " Added back in the pool " + DHCPScope.role + " on index " + strconv.Itoa(pool.(int)))
							DHCPScope.available.Add(uint32(pool.(int)))
						})

						DHCPScope.hwcache = hwcache

						xid := cache.New(time.Duration(4)*time.Second, 2*time.Second)

						DHCPScope.xid = xid

						initiaLease(&DHCPScope)
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
		d.intsNet = append(d.intsNet, ethIf)

	}
}
