package main

import (
	"log"
	"math"

	"context"
	_ "expvar"
	"net"
	"net/http"
	_ "net/http/pprof"
	"strconv"
	"time"

	"bitbucket.org/oeufdure/pfconfigdriver"
	"github.com/RoaringBitmap/roaring"
	dhcp "github.com/krolaw/dhcp4"
	"github.com/patrickmn/go-cache"
	netadv "github.com/simlelievre/go-netadv"
)

var DHCPConfig *Interfaces

var ctx = context.Background()

type DHCPHandler struct {
	ip            net.IP        // Server IP to use
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

func main() {

	// Read pfconfig
	DHCPConfig = newDHCPConfig()
	DHCPConfig.readConfig()

	// Queue value
	var (
		maxQueueSize = 100
		maxWorkers   = 50
	)

	// create job channel
	jobs := make(chan job, maxQueueSize)

	// create workers
	for i := 1; i <= maxWorkers; i++ {
		go func(i int) {
			for j := range jobs {
				doWork(i, j)
			}
		}(i)
	}

	// Unicast listener
	for _, v := range DHCPConfig.intsNet {
		v := v
		for net := range v.network {
			net := net
			go func() {
				v.runUnicast(jobs, v.network[net].dhcpHandler)
			}()
		}
	}

	// Broadcast listener
	for _, v := range DHCPConfig.intsNet {
		v := v
		go func() {
			v.run(jobs)
		}()
	}
	// Api
	log.Fatal(http.ListenAndServe(":22222", nil))
}

// Broadcast runner
func (h *Interface) run(jobs chan job) {
	ListenAndServeIf(h.Name, h, jobs)

}

// Unicast runner
func (h *Interface) runUnicast(jobs chan job, handler DHCPHandler) {
	ListenAndServeIfUnicast(h.Name, h, jobs, handler)
}

func (h *Interface) ServeDHCP(p dhcp.Packet, msgType dhcp.MessageType, options dhcp.Options) (answer Answer) {

	var handler DHCPHandler
	answer.MAC = p.CHAddr()
	answer.SrcIP = h.Ipv4

	// Detect the handler to use (config)
	for _, v := range h.network {
		if v.dhcpHandler.layer2 && p.GIAddr().Equal(net.IPv4zero) {
			// Ip per role ?
			if v.splittednet == true {
				// TO DO use a cache
				node := NodeInformation(p.CHAddr())

				var category string
				var nodeinfo = node.Result[0]
				// Undefined role then use the registration one
				if nodeinfo.Category == "" {
					category = "registration"
				} else {
					category = nodeinfo.Category
				}

				if v.dhcpHandler.role == category {
					handler = v.dhcpHandler
					answer.SrcIP = handler.ip
					break
				}
			}
		} else {
			handler = v.dhcpHandler
			break
		}

		if !p.GIAddr().Equal(net.IPv4zero) && v.network.Contains(p.GIAddr()) {
			handler = v.dhcpHandler
			break
		}
	}
	if len(handler.ip) == 0 {
		return answer
	}

	switch msgType {

	case dhcp.Discover:
		var free int
		i := handler.available.Iterator()

		// Search in the cache if the mac address already get assigned
		if x, found := handler.hwcache.Get(p.CHAddr().String()); found {
			free = x.(int)

			handler.hwcache.Set(p.CHAddr().String(), free, handler.leaseDuration)
			goto reply
		}

		// Search for the next available ip in the pool
		if i.HasNext() {
			element := i.Next()
			free = int(element)
			handler.available.Remove(element)
			handler.hwcache.Set(p.CHAddr().String(), free, handler.leaseDuration)
		} else {
			return answer
		}

	reply:

		answer.IP = dhcp.IPAdd(handler.start, free)
		answer.Iface = h.intNet
		answer.D = dhcp.ReplyPacket(p, dhcp.Offer, handler.ip, answer.IP, handler.leaseDuration,
			handler.options.SelectOrderOrAll(options[dhcp.OptionParameterRequestList]))

		return answer

	case dhcp.Request:

		if server, ok := options[dhcp.OptionServerIdentifier]; ok && (!net.IP(server).Equal(h.Ipv4) && !net.IP(server).Equal(handler.ip)) {
			return answer // Message not for this dhcp server
		}
		reqIP := net.IP(options[dhcp.OptionRequestedIPAddress])
		if reqIP == nil {
			reqIP = net.IP(p.CIAddr())
		}
		answer.IP = reqIP
		answer.Iface = h.intNet

		if len(reqIP) == 4 && !reqIP.Equal(net.IPv4zero) {
			if leaseNum := dhcp.IPRange(handler.start, reqIP) - 1; leaseNum >= 0 && leaseNum < handler.leaseRange {
				if _, found := handler.hwcache.Get(p.CHAddr().String()); found {
					answer.D = dhcp.ReplyPacket(p, dhcp.ACK, handler.ip, reqIP, handler.leaseDuration,
						handler.options.SelectOrderOrAll(options[dhcp.OptionParameterRequestList]))
					return answer
				}
			}
		}
		answer.D = dhcp.ReplyPacket(p, dhcp.NAK, handler.ip, nil, 0, nil)

	case dhcp.Release, dhcp.Decline:

		if x, found := handler.hwcache.Get(p.CHAddr().String()); found {
			handler.available.Add(uint32(x.(int)))
			handler.hwcache.Delete(p.CHAddr().String())
		}
	}
	return answer
}

func (d *Interfaces) readConfig() {

	var interfaces pfconfigdriver.ListenInts
	pfconfigdriver.FetchDecodeSocketStruct(ctx, &interfaces)

	var keyConfNet pfconfigdriver.PfconfigKeys
	keyConfNet.PfconfigNS = "config::Network"

	var ConfNet pfconfigdriver.NetworkConf
	pfconfigdriver.FetchDecodeSocketStruct(ctx, &keyConfNet)

	for _, v := range interfaces.Element {
		eth, _ := net.InterfaceByName(v)
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
				ConfNet.PfconfigHashNS = key
				pfconfigdriver.FetchDecodeSocketStruct(ctx, &ConfNet)

				if NetIP.Contains(net.ParseIP(ConfNet.Dns)) {
					// IP per role
					if ConfNet.SplitNetwork == "enabled" {
						var keyConfRoles pfconfigdriver.PfconfigKeys
						keyConfRoles.PfconfigNS = "config::Roles"

						pfconfigdriver.FetchDecodeSocketStruct(ctx, &keyConfRoles)

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
							hwcache := cache.New(time.Duration(seconds)*time.Second, (time.Duration(seconds)*time.Second)+10*time.Duration(seconds))

							hwcache.OnEvicted(func(nic string, pool interface{}) {
								DHCPScope.available.Add(uint32(pool.(int)))
							})

							DHCPScope.hwcache = hwcache

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
						DHCPScope.start = net.ParseIP(ConfNet.DhcpStart)
						seconds, _ := strconv.Atoi(ConfNet.DhcpDefaultLeaseTime)
						DHCPScope.leaseDuration = time.Duration(seconds) * time.Second
						DHCPScope.leaseRange = dhcp.IPRange(net.ParseIP(ConfNet.DhcpStart), net.ParseIP(ConfNet.DhcpEnd))

						// Initialize roaring bitmap
						available := roaring.New()
						available.AddRange(0, uint64(dhcp.IPRange(net.ParseIP(ConfNet.DhcpStart), net.ParseIP(ConfNet.DhcpEnd))))
						DHCPScope.available = available

						// Initialize hardware cache
						hwcache := cache.New(time.Duration(seconds)*time.Second, (time.Duration(seconds)*time.Second)+10*time.Duration(seconds))

						hwcache.OnEvicted(func(nic string, pool interface{}) {
							DHCPScope.available.Add(uint32(pool.(int)))
						})

						DHCPScope.hwcache = hwcache

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

func inc(ip net.IP) {
	for j := len(ip) - 1; j >= 0; j-- {
		ip[j]++
		if ip[j] > 0 {
			break
		}
	}
}

func dec(ip net.IP) {
	for j := len(ip) - 1; j >= 0; j-- {
		ip[j]--
		if ip[j] == 255 {
			continue
		}
		if ip[j] > 0 {
			break
		}
	}
}
