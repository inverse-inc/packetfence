package main

import (
	"fmt"
	"log"
	"math/rand"
	"net/http"

	"bitbucket.org/oeufdure/pfconfigdriver"
	dhcp "github.com/krolaw/dhcp4"

	"context"
	_ "expvar"
	"net"
	_ "net/http/pprof"
	"strconv"
	"time"
)

var DHCPConfig *Interfaces

var ctx = context.Background()

type job struct {
	p       dhcp.Packet
	msgType dhcp.MessageType
	options dhcp.Options
	handler Handler
	name    string
}

type lease struct {
	nic    string    // Client's CHAddr
	expiry time.Time // When the lease expires
}

type DHCPHandler struct {
	ip            net.IP        // Server IP to use
	options       dhcp.Options  // Options to send to DHCP Clients
	start         net.IP        // Start of IP range to distribute
	leaseRange    int           // Number of IPs to distribute (starting from start)
	leaseDuration time.Duration // Lease period
	leases        map[int]lease // Map to keep track of leases
	layer2        bool
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
}

func newDHCPConfig() *Interfaces {
	var p Interfaces
	return &p
}

func doWork(id int, jobe job) {
	var ans Answer
	fmt.Printf("worker%d: started %s\n", id, jobe.name)
	if ans = jobe.handler.ServeDHCP(jobe.p, jobe.msgType, jobe.options); ans.D != nil {
		client, _ := NewRawClient(ans.Iface)
		client.sendDHCP(ans.MAC, ans.D, ans.IP, ans.SrcIP)
		client.Close()
	}

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

	for _, v := range DHCPConfig.intsNet {
		v := v
		go func() {
			v.run(jobs)
		}()
	}
	log.Fatal(http.ListenAndServe(":22222", nil))
}

func (h *Interface) run(jobs chan job) {
	// spew.Dump(h)
	ListenAndServeIf(h.Name, h, jobs)
}

func (h *Interface) ServeDHCP(p dhcp.Packet, msgType dhcp.MessageType, options dhcp.Options) (answer Answer) {

	var handler DHCPHandler
	answer.MAC = p.CHAddr()
	answer.SrcIP = h.Ipv4

	// Detect the  handler to use (config)
	if p.GIAddr().Equal(net.IPv4zero) {
		for _, v := range h.network {
			if v.dhcpHandler.layer2 {
				handler = v.dhcpHandler
				break
			}
		}
	}
	if len(handler.ip) == 0 {
		return answer
	}

	switch msgType {

	case dhcp.Discover:

		// Need to be reworked to have a distributed ip range
		free, nic := -1, p.CHAddr().String()
		for i, v := range handler.leases { // Find previous lease
			if v.nic == nic {
				free = i
				goto reply
			}
		}
		if free = handler.freeLease(); free == -1 {
			return
		}

	reply:
		answer.IP = dhcp.IPAdd(handler.start, free)
		answer.Iface = h.intNet

		answer.D = dhcp.ReplyPacket(p, dhcp.Offer, handler.ip, answer.IP, handler.leaseDuration,
			handler.options.SelectOrderOrAll(options[dhcp.OptionParameterRequestList]))
		return answer

	case dhcp.Request:
		if server, ok := options[dhcp.OptionServerIdentifier]; ok && !net.IP(server).Equal(h.Ipv4) {
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
				if l, exists := handler.leases[leaseNum]; !exists || l.nic == p.CHAddr().String() {

					handler.leases[leaseNum] = lease{nic: p.CHAddr().String(), expiry: time.Now().Add(handler.leaseDuration)}
					answer.D = dhcp.ReplyPacket(p, dhcp.ACK, handler.ip, reqIP, handler.leaseDuration,
						handler.options.SelectOrderOrAll(options[dhcp.OptionParameterRequestList]))
					return answer
				}
			}
		}
		answer.D = dhcp.ReplyPacket(p, dhcp.NAK, handler.ip, nil, 0, nil)

	case dhcp.Release, dhcp.Decline:
		nic := p.CHAddr().String()
		for i, v := range handler.leases {
			if v.nic == nic {
				delete(handler.leases, i)
				break
			}
		}
	}

	return answer
}

func (h *DHCPHandler) freeLease() int {
	now := time.Now()
	b := rand.Intn(h.leaseRange) // Try random first
	for _, v := range [][]int{[]int{b, h.leaseRange}, []int{0, b}} {
		for i := v[0]; i < v[1]; i++ {
			if l, ok := h.leases[i]; !ok || l.expiry.Before(now) {
				return i
			}
		}
	}
	return -1
}

func (d *Interfaces) readConfig() {
	// var ethIfs Interfaces

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
					//Need to find a way to be able to change values dynamically
					var DHCPNet Network
					var DHCPScope DHCPHandler
					DHCPNet.network.IP = net.ParseIP(key)
					DHCPNet.network.Mask = net.IPMask(net.ParseIP(ConfNet.Netmask))
					DHCPScope.ip = IP.To4()
					DHCPScope.start = net.ParseIP(ConfNet.DhcpStart)
					seconds, _ := strconv.Atoi(ConfNet.DhcpDefaultLeaseTime)
					DHCPScope.leaseDuration = time.Duration(seconds) * time.Second
					DHCPScope.leaseRange = dhcp.IPRange(net.ParseIP(ConfNet.DhcpStart), net.ParseIP(ConfNet.DhcpEnd))
					DHCPScope.leases = make(map[int]lease, 10)
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
		//spew.Dump(ethIf)
		d.intsNet = append(d.intsNet, ethIf)

	}
}
