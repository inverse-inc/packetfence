package main

import (
	"database/sql"
	"encoding/binary"
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
	"github.com/coreos/go-systemd/daemon"
	netadv "github.com/fdurand/go-netadv"
	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
	dhcp "github.com/krolaw/dhcp4"
	"github.com/patrickmn/go-cache"
)

var DHCPConfig *Interfaces
var database *sql.DB

var GlobalIpCache *cache.Cache
var GlobalMacCache *cache.Cache
var GlobalOptionMacCache *cache.Cache

// Control
var ControlOut map[string]chan interface{}
var ControlIn map[string]chan interface{}

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

	// Initialize IP cache
	GlobalIpCache = cache.New(5*time.Minute, 10*time.Minute)
	// Initialize Mac cache
	GlobalMacCache = cache.New(5*time.Minute, 10*time.Minute)

	GlobalOptionMacCache = cache.New(60*time.Minute, 61*time.Minute)

	// Read DB config
	configDatabase := readDBConfig()
	connectDB(configDatabase, database)

	// Read pfconfig
	DHCPConfig = newDHCPConfig()
	DHCPConfig.readConfig()

	// Queue value
	var (
		maxQueueSize = 100
		maxWorkers   = 50
	)

	ControlIn = make(map[string]chan interface{})
	ControlOut = make(map[string]chan interface{})

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
		// Create a channel for each interfaces
		channelIn := make(chan interface{})
		channelOut := make(chan interface{})
		ControlIn[v.Name] = channelIn
		ControlOut[v.Name] = channelOut
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

	router := mux.NewRouter()
	router.HandleFunc("/help/", handleHelp).Methods("GET")
	router.HandleFunc("/mac2ip/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}", handleMac2Ip).Methods("GET")
	router.HandleFunc("/ip2mac/{ip:(?:[0-9]{1,3}.){3}.(?:[0-9]{1,3})}", handleIP2Mac).Methods("GET")
	router.HandleFunc("/stats/{int:.*}", handleStats).Methods("GET")
	// router.HandleFunc("/parking/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}", handleParking).Methods("GET")
	router.HandleFunc("/options/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}/{options:.*}", handleOverrideOptions).Methods("POST")
	router.HandleFunc("/removeoptions/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}", handleOverrideOptions).Methods("GET")
	// Api
	l, err := net.Listen("tcp", ":22222")
	if err != nil {
		log.Panicf("cannot listen: %s", err)
	}
	daemon.SdNotify(false, "READY=1")

	go func() {
		interval, err := daemon.SdWatchdogEnabled(false)
		if err != nil || interval == 0 {
			return
		}
		for {
			_, err := http.Get("http://127.0.0.1:22222")
			if err == nil {
				daemon.SdNotify(false, "WATCHDOG=1")
			}
			time.Sleep(interval / 3)
		}
	}()
	http.Serve(l, router)
}

// Broadcast runner
func (h *Interface) run(jobs chan job) {

	go func() {
		stats := make(map[string]Stats)
		inchannel := ControlIn[h.Name]
		outchannel := ControlOut[h.Name]
		for {

			Request := <-inchannel
			if Request.(ApiReq).Req == "stats" {
				for _, v := range h.network {
					var statistiques roaring.Statistics
					statistiques = v.dhcpHandler.available.Stats()
					stats[v.network.String()] = Stats{EthernetName: Request.(ApiReq).NetInterface, Net: v.network.String(), Free: int(statistiques.RunContainerValues) + 1}
				}
				outchannel <- stats
			}
			// if Request.(ApiReq).Req == "parking" {
			// 	if x, found := h.network[Request.(ApiReq).NetWork].dhcpHandler.hwcache.Get(Request.(ApiReq).Mac); found {
			// 		free := x.(int)
			// 		h.network[Request.(ApiReq).NetWork].dhcpHandler.hwcache.Set(Request.(ApiReq).Mac, free, (time.Duration(3600) * time.Second))
			// 	}
			// }
		}
	}()
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
	var NodeCache *cache.Cache
	NodeCache = cache.New(3*time.Second, 5*time.Second)
	var node NodeInfo
	for _, v := range h.network {

		// Case of a l2 dhcp request
		if v.dhcpHandler.layer2 && p.GIAddr().Equal(net.IPv4zero) {

			// Ip per role ?
			if v.splittednet == true {

				if x, found := NodeCache.Get(p.CHAddr().String()); found {
					node = x.(NodeInfo)
				} else {
					node = NodeInformation(p.CHAddr())
				}

				var category string
				var nodeinfo = node.Result[0]
				// Undefined role then use the registration one
				if nodeinfo.Category == "" || nodeinfo.Status == "unreg" {
					category = "registration"
				} else {
					category = nodeinfo.Category
				}

				if v.dhcpHandler.role == category {
					handler = v.dhcpHandler
					answer.SrcIP = handler.ip
					break
				}
				continue
			} else {
				// Case we are in L3
				if !p.CIAddr().Equal(net.IPv4zero) && !v.network.Contains(p.CIAddr()) {
					continue
				}
				handler = v.dhcpHandler
				break
			}
		}
		// Case dhcprequest from an already assigned l3 ip address
		if p.GIAddr().Equal(net.IPv4zero) && v.network.Contains(p.CIAddr()) {
			handler = v.dhcpHandler
			break
		}

		if (!p.GIAddr().Equal(net.IPv4zero) && v.network.Contains(p.GIAddr())) || v.network.Contains(p.CIAddr()) {
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
			handler.hwcache.Set(p.CHAddr().String(), free, handler.leaseDuration+(time.Duration(15)*time.Second))
			goto reply
		}

		// Search for the next available ip in the pool
		if i.HasNext() {
			element := i.Next()
			free = int(element)
			handler.available.Remove(element)
			handler.hwcache.Set(p.CHAddr().String(), free, handler.leaseDuration+(time.Duration(15)*time.Second))
		} else {
			return answer
		}

	reply:

		answer.IP = dhcp.IPAdd(handler.start, free)
		answer.Iface = h.intNet
		// Add options on the fly
		GlobalOptions := handler.options
		leaseDuration := handler.leaseDuration
		// Add options on the fly
		if x, found := GlobalOptionMacCache.Get(p.CHAddr().String()); found {
			for key, value := range x.(map[dhcp.OptionCode][]byte) {
				if key == dhcp.OptionIPAddressLeaseTime {
					seconds, _ := strconv.Atoi(string(value))
					leaseDuration = time.Duration(seconds) * time.Second
				}
				GlobalOptions[key] = value
			}
		}

		answer.D = dhcp.ReplyPacket(p, dhcp.Offer, handler.ip, answer.IP, leaseDuration,
			GlobalOptions.SelectOrderOrAll(options[dhcp.OptionParameterRequestList]))

		return answer

	case dhcp.Request:
		// Some client will not send OptionServerIdentifier
		// if server, ok := options[dhcp.OptionServerIdentifier]; ok && (!net.IP(server).Equal(h.Ipv4) && !net.IP(server).Equal(handler.ip)) {
		// 	return answer // Message not for this dhcp server
		// }
		reqIP := net.IP(options[dhcp.OptionRequestedIPAddress])
		if reqIP == nil {
			reqIP = net.IP(p.CIAddr())
		}
		answer.IP = reqIP
		answer.Iface = h.intNet

		if len(reqIP) == 4 && !reqIP.Equal(net.IPv4zero) {
			if leaseNum := dhcp.IPRange(handler.start, reqIP) - 1; leaseNum >= 0 && leaseNum < handler.leaseRange {
				if index, found := handler.hwcache.Get(p.CHAddr().String()); found {
					GlobalOptions := handler.options
					leaseDuration := handler.leaseDuration
					// Add options on the fly
					if x, found := GlobalOptionMacCache.Get(p.CHAddr().String()); found {
						for key, value := range x.(map[dhcp.OptionCode][]byte) {
							if key == dhcp.OptionIPAddressLeaseTime {
								seconds, _ := strconv.Atoi(string(value))
								leaseDuration = time.Duration(seconds) * time.Second
							}
							GlobalOptions[key] = value
						}
					}
					answer.D = dhcp.ReplyPacket(p, dhcp.ACK, handler.ip, reqIP, leaseDuration,
						GlobalOptions.SelectOrderOrAll(options[dhcp.OptionParameterRequestList]))
					// Update Global Caches
					GlobalIpCache.Set(reqIP.String(), p.CHAddr().String(), leaseDuration+(time.Duration(15)*time.Second))
					GlobalMacCache.Set(p.CHAddr().String(), reqIP.String(), leaseDuration+(time.Duration(15)*time.Second))
					// Update the cache
					handler.hwcache.Set(p.CHAddr().String(), index, leaseDuration+(time.Duration(15)*time.Second))
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
				var ConfNet pfconfigdriver.NetworkConf
				ConfNet.PfconfigHashNS = key

				pfconfigdriver.FetchDecodeSocketStruct(ctx, &ConfNet)
				if (NetIP.Contains(net.ParseIP(ConfNet.DhcpStart)) && NetIP.Contains(net.ParseIP(ConfNet.DhcpEnd))) || NetIP.Contains(net.ParseIP(ConfNet.NextHop)) {
					// NetIP.Contains(net.ParseIP(ConfNet.Dns)) &&
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

// inc function use to increment an ip
func inc(ip net.IP) {
	for j := len(ip) - 1; j >= 0; j-- {
		ip[j]++
		if ip[j] > 0 {
			break
		}
	}
}

// inc function use to decrement an ip
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

// readDBConfig read pfconfig database configuration
func readDBConfig() pfconfigdriver.PfconfigDatabase {
	var sections pfconfigdriver.PfconfigDatabase
	sections.PfconfigNS = "config::Pf"
	sections.PfconfigMethod = "hash_element"
	sections.PfconfigHashNS = "database"

	pfconfigdriver.FetchDecodeSocketStruct(ctx, &sections)
	return sections
}

// connectDB connect to the database
func connectDB(configDatabase pfconfigdriver.PfconfigDatabase, db *sql.DB) {
	database, _ = sql.Open("mysql", configDatabase.DBUser+":"+configDatabase.DBPassword+"@tcp("+configDatabase.DBHost+":"+configDatabase.DBPort+")/"+configDatabase.DBName+"?parseTime=true")

}

// initiaLease fetch the database to remove already assigned ip addresses
func initiaLease(dhcpHandler *DHCPHandler) {
	// Need to calculate the end ip because of the ip per role feature
	endip := binary.BigEndian.Uint32(dhcpHandler.start.To4()) + uint32(dhcpHandler.leaseRange) - uint32(1)
	a := make([]byte, 4)
	binary.BigEndian.PutUint32(a, endip)
	ipend := net.IPv4(a[0], a[1], a[2], a[3])

	rows, err := database.Query("select ip,mac,end_time from ip4log where inet_aton(ip) between inet_aton(?) and inet_aton(?) and (end_time = 0 OR  end_time > NOW()) ORDER BY ip", dhcpHandler.start.String(), ipend.String())
	if err != nil {
		log.Fatal(err)
	}
	defer rows.Close()
	var (
		ipstr    string
		mac      string
		end_time time.Time
	)
	for rows.Next() {
		err := rows.Scan(&ipstr, &mac, &end_time)
		if err != nil {
			log.Fatal(err)
		}

		// Calculate the leasetime from the date in the database
		now := time.Now()
		leaseDuration := end_time.Sub(now)
		ip := net.ParseIP(ipstr)

		// Calculate the position for the roaring bitmap
		position := uint32(binary.BigEndian.Uint32(ip.To4())) - uint32(binary.BigEndian.Uint32(dhcpHandler.start.To4()))
		// Remove the position in the roaming bitmap
		dhcpHandler.available.Remove(position)
		// Add the mac in the cache
		dhcpHandler.hwcache.Set(mac, int(position), leaseDuration)
		GlobalIpCache.Set(ipstr, mac, leaseDuration)
		GlobalMacCache.Set(mac, ipstr, leaseDuration)
	}
}

func InterfaceScopeFromMac(MAC string) (string, string) {
	var NetInterface string
	var NetWork string
	if index, found := GlobalMacCache.Get(MAC); found {
		for _, v := range DHCPConfig.intsNet {
			v := v
			for network := range v.network {
				if v.network[network].network.Contains(net.ParseIP(index.(string))) {
					NetInterface = v.Name
					NetWork = v.network[network].network.String()
				}
			}
		}
	}
	return NetInterface, NetWork
}
