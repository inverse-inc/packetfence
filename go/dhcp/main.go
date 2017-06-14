package main

import (
	"database/sql"
	"fmt"
	"log"

	"context"
	_ "expvar"
	"net"
	"net/http"
	_ "net/http/pprof"
	"strconv"
	"time"

	"github.com/RoaringBitmap/roaring"
	"github.com/coreos/etcd/client"
	"github.com/coreos/go-systemd/daemon"
	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	dhcp "github.com/krolaw/dhcp4"
	"github.com/patrickmn/go-cache"
)

var DHCPConfig *Interfaces
var database *sql.DB

var GlobalIpCache *cache.Cache
var GlobalMacCache *cache.Cache

// Control
var ControlOut map[string]chan interface{}
var ControlIn map[string]chan interface{}

var VIP map[string]bool
var VIPIp map[string]net.IP

var ctx = context.Background()

var Capi *client.Config

func main() {
	// Initialize etcd config
	Capi = etcdInit()

	// Initialize IP cache
	GlobalIpCache = cache.New(5*time.Minute, 10*time.Minute)
	// Initialize Mac cache
	GlobalMacCache = cache.New(5*time.Minute, 10*time.Minute)

	// Read DB config
	configDatabase := readDBConfig()
	connectDB(configDatabase, database)

	VIP = make(map[string]bool)
	VIPIp = make(map[string]net.IP)

	go func() {
		var interfaces pfconfigdriver.ListenInts
		pfconfigdriver.FetchDecodeSocket(ctx, &interfaces)
		for {
			DHCPConfig.detectVIP(interfaces)

			time.Sleep(3 * time.Second)
		}
	}()

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
				v.runUnicast(jobs, v.network[net].dhcpHandler.ip)
			}()

			// We only need one listener per ip
			break
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
	router.HandleFunc("/options/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}/{options:.*}", handleOverrideOptions).Methods("POST")
	router.HandleFunc("/removeoptions/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}", handleRemoveOptions).Methods("GET")

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

	// Communicate with the server that run on an interface
	go func() {
		stats := make(map[string]Stats)
		inchannel := ControlIn[h.Name]
		outchannel := ControlOut[h.Name]
		for {

			Request := <-inchannel
			// Send back stats
			if Request.(ApiReq).Req == "stats" {
				for _, v := range h.network {
					var statistiques roaring.Statistics
					statistiques = v.dhcpHandler.available.Stats()
					stats[v.network.String()] = Stats{EthernetName: Request.(ApiReq).NetInterface, Net: v.network.String(), Free: int(statistiques.RunContainerValues) + 1}
				}
				outchannel <- stats
			}
			// Update the lease
			if Request.(ApiReq).Req == "initialease" {
				for _, v := range h.network {
					initiaLease(&v.dhcpHandler)
				}
			}
		}
	}()
	ListenAndServeIf(h.Name, h, jobs)

}

// Unicast runner
func (h *Interface) runUnicast(jobs chan job, ip net.IP) {

	ListenAndServeIfUnicast(h.Name, h, jobs, ip)
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
	// Do we have the vip ?

	if VIP[h.Name] {
		fmt.Println("Process " + msgType.String() + " packet for " + p.CHAddr().String())
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
			var GlobalOptions dhcp.Options
			var options = make(map[dhcp.OptionCode][]byte)
			for key, value := range handler.options {
				options[key] = value
			}
			GlobalOptions = options
			leaseDuration := handler.leaseDuration
			// Add options on the fly
			x, err := decodeOptions(p.CHAddr().String())
			if err {
				for key, value := range x {
					if key == dhcp.OptionIPAddressLeaseTime {
						seconds, _ := strconv.Atoi(string(value))
						leaseDuration = time.Duration(seconds) * time.Second
						continue
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
						var GlobalOptions dhcp.Options
						var options = make(map[dhcp.OptionCode][]byte)
						for key, value := range handler.options {
							options[key] = value
						}
						GlobalOptions = options
						leaseDuration := handler.leaseDuration
						// Add options on the fly
						x, err := decodeOptions(p.CHAddr().String())
						if err {
							for key, value := range x {
								if key == dhcp.OptionIPAddressLeaseTime {
									seconds, _ := strconv.Atoi(string(value))
									leaseDuration = time.Duration(seconds) * time.Second
									continue
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
	answer.Iface = h.intNet
	answer.D = dhcp.ReplyPacket(p, dhcp.NAK, handler.ip, nil, 0, nil)
	return answer
}
