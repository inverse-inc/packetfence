package main

import (
	"math"
	"net"
	"strconv"
	"time"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/RoaringBitmap/roaring"
	netadv "github.com/fdurand/go-netadv"
	dhcp "github.com/krolaw/dhcp4"
	cache "github.com/patrickmn/go-cache"
)

type DHCPHandler struct {
	ip            net.IP // Server IP to use
	vip           net.IP
	options       dhcp.Options  // Options to send to DHCP Clients
	start         net.IP        // Start of IP range to distribute
	leaseRange    int           // Number of IPs to distribute (starting from start)
	leaseDuration time.Duration // Lease period
	hwcache       *cache.Cache
	available     *roaring.Bitmap // RoaringBitmap to keep trak of available ip
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
func readDBConfig() pfconfigdriver.PfconfigDatabase {
	var sections pfconfigdriver.PfconfigDatabase
	sections.PfconfigNS = "config::Pf"
	sections.PfconfigMethod = "hash_element"
	sections.PfconfigHashNS = "database"

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

		eth, _ := net.InterfaceByName(v)
		// TO DO Check if the interface exist
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
				var ConfNet pfconfigdriver.NetworkConf
				ConfNet.PfconfigHashNS = key

				pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)
				if (NetIP.Contains(net.ParseIP(ConfNet.DhcpStart)) && NetIP.Contains(net.ParseIP(ConfNet.DhcpEnd))) || NetIP.Contains(net.ParseIP(ConfNet.NextHop)) {
					// NetIP.Contains(net.ParseIP(ConfNet.Dns)) &&
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
							ip = append([]byte(nil), subnet.IP...)

							// First ip available in the scope (packetfence ip)
							inc(ip)
							DHCPNet.network.IP = append([]byte(nil), subnet.IP...)

							DHCPNet.network.Mask = subnet.Mask
							DHCPScope.ip = append([]byte(nil), ip...)

							// First ip available for endpoint
							inc(ip)
							DHCPScope.start = append([]byte(nil), ip...)
							var seconds int

							if Role == "registration" {
								// lease duration need to be low in registration role
								seconds, _ = strconv.Atoi("30")
							} else {
								seconds, _ = strconv.Atoi(ConfNet.DhcpDefaultLeaseTime)
							}
							DHCPScope.leaseDuration = time.Duration(seconds) * time.Second
							var ips net.IP

							for ipe := net.IPv4(subnet.IP[0], subnet.IP[1], subnet.IP[2], subnet.IP[3]); subnet.Contains(ipe); inc(ipe) {
								ips = append([]byte(nil), ipe...)
							}
							// Decrement twice to have the last ip available for the scope
							dec(ips)
							dec(ips)
							DHCPScope.leaseRange = dhcp.IPRange(ip, ips)

							// Initialize roaring bitmap
							available := roaring.New()
							available.AddRange(0, uint64(dhcp.IPRange(ip, ips)))
							DHCPScope.available = available

							// Initialize hardware cache
							hwcache := cache.New(time.Duration(seconds)*time.Second, (time.Duration(seconds)*time.Second)+10*time.Second)

							hwcache.OnEvicted(func(nic string, pool interface{}) {
								DHCPScope.available.Add(uint32(pool.(int)))
							})

							DHCPScope.hwcache = hwcache
							initiaLease(&DHCPScope)
							var options = make(map[dhcp.OptionCode][]byte)

							options[dhcp.OptionSubnetMask] = []byte(DHCPNet.network.Mask)
							options[dhcp.OptionDomainNameServer] = []byte(net.ParseIP(ConfNet.Dns).To4())
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
						//Need to find a way to be able to change values dynamically
						var DHCPNet Network
						var DHCPScope DHCPHandler
						DHCPNet.splittednet = false
						DHCPNet.network.IP = net.ParseIP(key)
						DHCPNet.network.Mask = net.IPMask(net.ParseIP(ConfNet.Netmask))
						DHCPScope.ip = IP.To4()
						if _, found := VIPIp[eth.Name]; found {
							DHCPScope.vip = VIPIp[eth.Name]
						}
						DHCPScope.start = net.ParseIP(ConfNet.DhcpStart)
						seconds, _ := strconv.Atoi(ConfNet.DhcpDefaultLeaseTime)
						DHCPScope.leaseDuration = time.Duration(seconds) * time.Second
						DHCPScope.leaseRange = dhcp.IPRange(net.ParseIP(ConfNet.DhcpStart), net.ParseIP(ConfNet.DhcpEnd))

						// Initialize roaring bitmap
						available := roaring.New()
						available.AddRange(0, uint64(dhcp.IPRange(net.ParseIP(ConfNet.DhcpStart), net.ParseIP(ConfNet.DhcpEnd))))
						DHCPScope.available = available

						// Initialize hardware cache
						hwcache := cache.New(time.Duration(seconds)*time.Second, (time.Duration(seconds)*time.Second)+10*time.Second)

						hwcache.OnEvicted(func(nic string, pool interface{}) {
							DHCPScope.available.Add(uint32(pool.(int)))
						})

						DHCPScope.hwcache = hwcache
						initiaLease(&DHCPScope)
						var options = make(map[dhcp.OptionCode][]byte)

						options[dhcp.OptionSubnetMask] = []byte(net.ParseIP(ConfNet.Netmask).To4())
						options[dhcp.OptionDomainNameServer] = []byte(net.ParseIP(ConfNet.Dns).To4())
						options[dhcp.OptionRouter] = []byte(net.ParseIP(ConfNet.Gateway).To4())
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
