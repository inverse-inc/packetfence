package main

import (
	"database/sql"
	"encoding/binary"
	"fmt"
	"strings"

	"context"
	_ "expvar"
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/coreos/go-systemd/daemon"
	"github.com/davecgh/go-spew/spew"
	"github.com/fdurand/arp"
	cache "github.com/fdurand/go-cache"
	"github.com/go-errors/errors"
	_ "github.com/go-sql-driver/mysql"
	"github.com/goji/httpauth"
	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/inverse-inc/packetfence/go/timedlock"
	dhcp "github.com/krolaw/dhcp4"
)

var DHCPConfig *Interfaces

var MySQLdatabase *sql.DB

var GlobalIpCache *cache.Cache
var GlobalMacCache *cache.Cache

var GlobalTransactionCache *cache.Cache
var GlobalTransactionLock *timedlock.RWLock

var RequestGlobalTransactionCache *cache.Cache

var VIP map[string]bool
var VIPIp map[string]net.IP

var ctx = context.Background()

var webservices pfconfigdriver.PfConfWebservices

var intNametoInterface map[string]*Interface

const FreeMac = "00:00:00:00:00:00"
const FakeMac = "ff:ff:ff:ff:ff:ff"

func main() {
	log.SetProcessName("pfdhcp")
	ctx = log.LoggerNewContext(ctx)
	arp.AutoRefresh(30 * time.Second)
	// Default http timeout
	http.DefaultClient.Timeout = 10 * time.Second

	// Initialize IP cache
	GlobalIpCache = cache.New(5*time.Minute, 10*time.Minute)
	// Initialize Mac cache
	GlobalMacCache = cache.New(5*time.Minute, 10*time.Minute)

	// Initialize transaction cache
	GlobalTransactionCache = cache.New(5*time.Minute, 10*time.Minute)
	GlobalTransactionLock = timedlock.NewRWLock()
	RequestGlobalTransactionCache = cache.New(5*time.Minute, 10*time.Minute)

	// Read DB config
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Database)
	configDatabase := pfconfigdriver.Config.PfConf.Database

	connectDB(configDatabase)

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
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Webservices)
	webservices = pfconfigdriver.Config.PfConf.Webservices

	// Queue value
	var (
		maxQueueSize = 100
		maxWorkers   = 100
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

	intNametoInterface = make(map[string]*Interface)

	// Unicast listener
	for _, v := range DHCPConfig.intsNet {
		v := v
		// Create a channel for each interfaces
		intNametoInterface[v.Name] = &v
		for net := range v.network {
			net := net
			go func() {
				v.runUnicast(jobs, v.network[net].dhcpHandler.ip, ctx)
			}()

			// We only need one listener per ip
			break
		}
	}

	// Broadcast listener
	for _, v := range DHCPConfig.intsNet {
		v := v
		go func() {
			v.run(jobs, ctx)
		}()
	}

	// Api
	router := mux.NewRouter()
	router.HandleFunc("/api/v1/dhcp/mac/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}", handleMac2Ip).Methods("GET")
	router.HandleFunc("/api/v1/dhcp/mac/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}", handleReleaseIP).Methods("DELETE")
	router.HandleFunc("/api/v1/dhcp/ip/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}", handleIP2Mac).Methods("GET")
	router.HandleFunc("/api/v1/dhcp/stats", handleAllStats).Methods("GET")
	router.HandleFunc("/api/v1/dhcp/stats/{int:.*}/{network:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}", handleStats).Methods("GET")
	router.HandleFunc("/api/v1/dhcp/stats/{int:.*}", handleStats).Methods("GET")
	router.HandleFunc("/api/v1/dhcp/debug/{int:.*}/{role:(?:[^/]*)}", handleDebug).Methods("GET")
	router.HandleFunc("/api/v1/dhcp/options/network/{network:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}", handleOverrideNetworkOptions).Methods("POST")
	router.HandleFunc("/api/v1/dhcp/options/network/{network:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}", handleRemoveNetworkOptions).Methods("DELETE")
	router.HandleFunc("/api/v1/dhcp/options/mac/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}", handleOverrideOptions).Methods("POST")
	router.HandleFunc("/api/v1/dhcp/options/mac/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}", handleRemoveOptions).Methods("DELETE")
	http.Handle("/", httpauth.SimpleBasicAuth(webservices.User, webservices.Pass)(router))

	srv := &http.Server{
		Addr:        "127.0.0.1:22222",
		IdleTimeout: 5 * time.Second,
		Handler:     router,
	}

	// Systemd
	daemon.SdNotify(false, "READY=1")

	go func() {
		interval, err := daemon.SdWatchdogEnabled(false)
		if err != nil || interval == 0 {
			return
		}
		cli := &http.Client{}
		for {
			req, err := http.NewRequest("GET", "http://127.0.0.1:22222", nil)
			if err != nil {
				log.LoggerWContext(ctx).Error(err.Error())
				continue
			}
			req.Close = true
			resp, err := cli.Do(req)
			time.Sleep(100 * time.Millisecond)
			if err != nil {
				log.LoggerWContext(ctx).Error(err.Error())
				continue
			}
			resp.Body.Close()

			if err == nil {
				daemon.SdNotify(false, "WATCHDOG=1")
			}
			time.Sleep(interval / 3)
		}
	}()
	srv.ListenAndServe()
}

// Broadcast Listener
func (h *Interface) run(jobs chan job, ctx context.Context) {

	ListenAndServeIf(h.Name, h, jobs, ctx)
}

// Unicast listener
func (h *Interface) runUnicast(jobs chan job, ip net.IP, ctx context.Context) {

	ListenAndServeIfUnicast(h.Name, h, jobs, ip, ctx)
}

func (h *Interface) ServeDHCP(ctx context.Context, p dhcp.Packet, msgType dhcp.MessageType) (answer Answer) {

	var handler DHCPHandler
	var NetScope net.IPNet
	options := p.ParseOptions()
	answer.MAC = p.CHAddr()
	answer.SrcIP = h.Ipv4
	answer.Iface = h.intNet

	ctx = log.AddToLogContext(ctx, "mac", answer.MAC.String())

	// Detect the handler to use (config)
	var NodeCache *cache.Cache
	NodeCache = cache.New(3*time.Second, 5*time.Second)
	var node NodeInfo
	for _, v := range h.network {

		// Case of a l2 dhcp request
		if v.dhcpHandler.layer2 && (p.GIAddr().Equal(net.IPv4zero) || v.network.Contains(p.CIAddr())) {

			// Ip per role ?
			if v.splittednet == true {

				if x, found := NodeCache.Get(p.CHAddr().String()); found {
					node = x.(NodeInfo)
				} else {
					node = NodeInformation(p.CHAddr(), ctx)
					NodeCache.Set(p.CHAddr().String(), node, 3*time.Second)
				}

				var category string
				var nodeinfo = node
				// Undefined role then use the registration one
				if nodeinfo.Category == "" || nodeinfo.Status == "unreg" {
					category = "registration"
				} else {
					category = nodeinfo.Category
				}

				if v.dhcpHandler.role == category {
					handler = *v.dhcpHandler
					NetScope = v.network
					answer.SrcIP = handler.ip
					break
				}
				continue
			} else {
				// Case we are in L3
				if !p.CIAddr().Equal(net.IPv4zero) && !v.network.Contains(p.CIAddr()) {
					continue
				}
				handler = *v.dhcpHandler
				NetScope = v.network
				break
			}
		}
		// Case dhcprequest from an already assigned l3 ip address
		if p.GIAddr().Equal(net.IPv4zero) && v.network.Contains(p.CIAddr()) {
			handler = *v.dhcpHandler
			NetScope = v.network
			break
		}

		if (!p.GIAddr().Equal(net.IPv4zero) && v.network.Contains(p.GIAddr())) || v.network.Contains(p.CIAddr()) {
			handler = *v.dhcpHandler
			NetScope = v.network
			break
		}
	}

	if len(handler.ip) == 0 {
		return answer
	}
	// Do we have the vip ?

	if VIP[h.Name] {

		defer recoverName(options)
		answer.Local = handler.layer2

		log.LoggerWContext(ctx).Debug(p.CHAddr().String() + " " + msgType.String() + " xID " + sharedutils.ByteToString(p.XId()))

		id, _ := GlobalTransactionLock.Lock()

		cacheKey := p.CHAddr().String() + " " + msgType.String() + " xID " + sharedutils.ByteToString(p.XId())
		if _, found := GlobalTransactionCache.Get(cacheKey); found {
			log.LoggerWContext(ctx).Debug("Not answering to packet. Already in progress")
			GlobalTransactionLock.Unlock(id)
			return answer
		} else {
			GlobalTransactionCache.Set(cacheKey, 1, time.Duration(1)*time.Second)
			GlobalTransactionLock.Unlock(id)
		}

		prettyType := "DHCP" + strings.ToUpper(msgType.String())
		clientMac := p.CHAddr().String()
		clientHostname := string(options[dhcp.OptionHostName])

		switch msgType {

		case dhcp.Discover:
			firstTry := true
			log.LoggerWContext(ctx).Info("DHCPDISCOVER from " + clientMac + " (" + clientHostname + ")")
			var free int
			// Static assign IP address ?
			if position, ok := handler.ipAssigned[p.CHAddr().String()]; ok {
				free = int(position)
				goto reply
			}
			// Search in the cache if the mac address already get assigned
			if x, found := handler.hwcache.Get(p.CHAddr().String()); found {
				log.LoggerWContext(ctx).Debug("Found in the cache that a IP has already been assigned")
				// Test if we find the the mac address at the index
				_, returnedMac, err := handler.available.GetMACIndex(uint64(x.(int)))
				if returnedMac == p.CHAddr().String() {
					free = x.(int)
				} else if returnedMac == FreeMac {
					// The index is free use it
					handler.hwcache.Delete(p.CHAddr().String())
					// Reserve the ip
					err, returnedMac = handler.available.ReserveIPIndex(uint64(x.(int)), p.CHAddr().String())
					if err != nil && returnedMac == p.CHAddr().String() {
						free = x.(int)
					} else {
						// Something went wrong to reserve the ip retry
						goto retry
					}
					// The ip asked is not the one we have retry
				} else {
					goto retry
				}

				// 5 seconds to send a request
				err = handler.hwcache.Replace(p.CHAddr().String(), free, time.Duration(5)*time.Second)
				if err != nil {
					return answer
				}
				goto reply
			}

		retry:
			// Search for the next available ip in the pool
			if handler.available.FreeIPsRemaining() > 0 {
				var element uint32
				// Check if the device request a specific ip
				if p.ParseOptions()[50] != nil && firstTry {
					log.LoggerWContext(ctx).Debug("Attempting to use the IP requested by the device")
					element = uint32(binary.BigEndian.Uint32(p.ParseOptions()[50])) - uint32(binary.BigEndian.Uint32(handler.start.To4()))
					// Test if we find the the mac address at the index
					_, returnedMac, err := handler.available.GetMACIndex(uint64(element))
					if returnedMac == p.CHAddr().String() {
						log.LoggerWContext(ctx).Debug("The IP asked by the device is available in the pool")
						free = int(element)
					} else if returnedMac == FreeMac {
						// The ip is free use it
						err, returnedMac = handler.available.ReserveIPIndex(uint64(element), p.CHAddr().String())
						// Reserve the ip
						if err != nil && returnedMac == p.CHAddr().String() {
							log.LoggerWContext(ctx).Debug("The IP asked by the device is available in the pool")
							free = int(element)
						}
					} else {
						// The ip is not available
						firstTry = false
						goto retry
					}
				}

				// If we still haven't found an IP address to offer, we get the next one
				if free == 0 {
					log.LoggerWContext(ctx).Debug("Grabbing next available IP")
					freeu64, _, err := handler.available.GetFreeIPIndex(p.CHAddr().String())

					if err != nil {
						log.LoggerWContext(ctx).Error("Unable to get free IP address, DHCP pool is full")
						return answer
					}
					free = int(freeu64)
				}

				// Lock it
				handler.hwcache.Set(p.CHAddr().String(), free, time.Duration(5)*time.Second)
				handler.xid.Set(sharedutils.ByteToString(p.XId()), 0, time.Duration(5)*time.Second)
				var inarp bool
				// Ping the ip address
				inarp = false
				// Layer 2 test (arp cache)
				if handler.layer2 {
					mac := arp.Search(dhcp.IPAdd(handler.start, free).String())
					if mac != "" && mac != FreeMac {
						if p.CHAddr().String() != mac {
							log.LoggerWContext(ctx).Info(p.CHAddr().String() + " in arp table Ip " + dhcp.IPAdd(handler.start, free).String() + " is already own by " + mac)
							inarp = true
						}
					}
				}
				// Layer 3 Test
				pingreply := sharedutils.Ping(dhcp.IPAdd(handler.start, free).String(), 1)
				if pingreply || inarp {
					// Found in the arp cache or able to ping it
					ipaddr := dhcp.IPAdd(handler.start, free)
					log.LoggerWContext(ctx).Info(p.CHAddr().String() + " Ip " + ipaddr.String() + " already in use, trying next")
					// Added back in the pool since it's not the dhcp server who gave it
					handler.hwcache.Delete(p.CHAddr().String())

					firstTry = false

					log.LoggerWContext(ctx).Info("Temporarily declaring " + ipaddr.String() + " as unusable")
					// Reserve with a fake mac
					handler.available.ReserveIPIndex(uint64(free), FakeMac)
					// Put it back into the available IPs in 10 minutes
					go func(ctx context.Context, free int, ipaddr net.IP) {
						time.Sleep(10 * time.Minute)
						log.LoggerWContext(ctx).Info("Releasing previously pingable IP " + ipaddr.String() + " back into the pool")
						handler.available.FreeIPIndex(uint64(free))
					}(ctx, free, ipaddr)
					free = 0
					goto retry
				}
				// 5 seconds to send a request
				handler.hwcache.Set(p.CHAddr().String(), free, time.Duration(5)*time.Second)
				handler.xid.Replace(sharedutils.ByteToString(p.XId()), 1, time.Duration(5)*time.Second)
			} else {
				log.LoggerWContext(ctx).Info(p.CHAddr().String() + " Nak No space left in the pool ")
				return answer
			}

		reply:

			answer.IP = dhcp.IPAdd(handler.start, free)
			answer.Iface = h.intNet
			// Add options on the fly
			var GlobalOptions dhcp.Options
			var options = make(map[dhcp.OptionCode][]byte)
			for key, value := range handler.options {
				if key == dhcp.OptionDomainNameServer || key == dhcp.OptionRouter {
					options[key] = ShuffleIP(value, int64(p.CHAddr()[5]))
				} else {
					options[key] = value
				}
			}
			GlobalOptions = options
			leaseDuration := handler.leaseDuration

			// Add network options on the fly
			x, err := decodeOptions(NetScope.IP.String())
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

			// Add device (mac) options on the fly
			x, err = decodeOptions(p.CHAddr().String())
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

			log.LoggerWContext(ctx).Info("DHCPOFFER on " + answer.IP.String() + " to " + clientMac + " (" + clientHostname + ")")

			answer.D = dhcp.ReplyPacket(p, dhcp.Offer, handler.ip.To4(), answer.IP, leaseDuration,
				GlobalOptions.SelectOrderOrAll(options[dhcp.OptionParameterRequestList]))

			return answer

		case dhcp.Request, dhcp.Inform:
			reqIP := net.IP(options[dhcp.OptionRequestedIPAddress])
			if reqIP == nil {
				reqIP = net.IP(p.CIAddr())
			}

			log.LoggerWContext(ctx).Info(prettyType + " for " + reqIP.String() + " from " + clientMac + " (" + clientHostname + ")")

			cacheKey := p.CHAddr().String() + " " + msgType.String() + " xID " + sharedutils.ByteToString(p.XId())

			// In the event of a DHCPREQUEST, we do not reply if we're not the server ID in the request
			serverIdBytes := options[dhcp.OptionServerIdentifier]
			if len(serverIdBytes) == 4 {
				serverId := net.IPv4(serverIdBytes[0], serverIdBytes[1], serverIdBytes[2], serverIdBytes[3])
				if !serverId.Equal(handler.ip.To4()) {
					log.LoggerWContext(ctx).Debug(fmt.Sprintf("Not replying to %s because this server didn't perform the offer (offered by %s, we are %s)", prettyType, serverId, handler.ip.To4()))
					return Answer{}
				}
			}

			answer.IP = reqIP
			answer.Iface = h.intNet

			var Reply bool
			var Index int
			var Static bool

			Static = false
			// Valid IP
			if len(reqIP) == 4 && !reqIP.Equal(net.IPv4zero) {
				// Requested IP is in the pool ?
				if leaseNum := dhcp.IPRange(handler.start, reqIP) - 1; leaseNum >= 0 && leaseNum < handler.leaseRange {
					// Static assigned ip ?
					if position, ok := handler.ipAssigned[p.CHAddr().String()]; ok {
						Static = true
						if int(position) == leaseNum {
							Index = int(position)
							Reply = true
						} else {
							Reply = false
						}
					}
					if Static == false {
						// Requested IP is in the cache ?
						if index, found := handler.hwcache.Get(p.CHAddr().String()); found {
							// Requested IP is equal to what we have in the cache ?

							if dhcp.IPAdd(handler.start, index.(int)).Equal(reqIP) {
								id, _ := GlobalTransactionLock.Lock()
								if _, found = RequestGlobalTransactionCache.Get(cacheKey); found {
									log.LoggerWContext(ctx).Debug("Not answering to REQUEST. Already processed")
									Reply = false
									GlobalTransactionLock.Unlock(id)
									return answer
								} else {
									Reply = true
									Index = index.(int)
									RequestGlobalTransactionCache.Set(cacheKey, 1, time.Duration(1)*time.Second)
									GlobalTransactionLock.Unlock(id)
								}
								// So remove the ip from the cache
							} else {
								Reply = false
								log.LoggerWContext(ctx).Info(p.CHAddr().String() + " Asked for an IP " + reqIP.String() + " that hasnt been assigned by Offer " + dhcp.IPAdd(handler.start, index.(int)).String() + " xID " + sharedutils.ByteToString(p.XId()))
								if index, found = handler.xid.Get(string(binary.BigEndian.Uint32(p.XId()))); found {
									if index.(int) == 1 {
										handler.hwcache.Delete(p.CHAddr().String())
									}
								}
							}
						} else {
							// Not in the cache so we don't reply
							log.LoggerWContext(ctx).Debug(fmt.Sprintf("Not replying to %s because this server didn't perform the offer", prettyType))
							return Answer{}
						}
					}
				}

				if Reply {

					var GlobalOptions dhcp.Options
					var options = make(map[dhcp.OptionCode][]byte)
					for key, value := range handler.options {
						if key == dhcp.OptionDomainNameServer || key == dhcp.OptionRouter {
							options[key] = ShuffleIP(value, int64(p.CHAddr()[5]))
						} else {
							options[key] = value
						}
					}
					GlobalOptions = options
					leaseDuration := handler.leaseDuration

					// Add network options on the fly
					x, err := decodeOptions(NetScope.IP.String())
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

					// Add devices options on the fly
					x, err = decodeOptions(p.CHAddr().String())
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

					answer.D = dhcp.ReplyPacket(p, dhcp.ACK, handler.ip.To4(), reqIP, leaseDuration,
						GlobalOptions.SelectOrderOrAll(options[dhcp.OptionParameterRequestList]))
					var cacheDuration time.Duration
					if leaseDuration < time.Duration(60)*time.Second {
						cacheDuration = time.Duration(61) * time.Second
					} else {
						cacheDuration = leaseDuration + (time.Duration(60) * time.Second)
					}

					// Update Global Caches
					GlobalIpCache.Set(reqIP.String(), p.CHAddr().String(), cacheDuration)
					GlobalMacCache.Set(p.CHAddr().String(), reqIP.String(), cacheDuration)
					// Update the cache
					log.LoggerWContext(ctx).Info("DHCPACK on " + reqIP.String() + " to " + clientMac + " (" + clientHostname + ")")

					handler.hwcache.Set(p.CHAddr().String(), Index, cacheDuration)
					handler.available.ReserveIPIndex(uint64(Index), p.CHAddr().String())

				} else {
					log.LoggerWContext(ctx).Info("DHCPNAK on " + reqIP.String() + " to " + clientMac)
					answer.D = dhcp.ReplyPacket(p, dhcp.NAK, handler.ip.To4(), nil, 0, nil)
				}
				return answer
			}

		case dhcp.Release:
			reqIP := net.IP(options[dhcp.OptionRequestedIPAddress])
			if reqIP == nil {
				reqIP = net.IP(p.CIAddr())
			}
			if leaseNum := dhcp.IPRange(handler.start, reqIP) - 1; leaseNum >= 0 && leaseNum < handler.leaseRange {
				// Static ip address assigned ?
				if position, ok := handler.ipAssigned[p.CHAddr().String()]; ok {
					if int(position) == leaseNum {
						return answer
					}

				}
				if x, found := handler.hwcache.Get(p.CHAddr().String()); found {
					if leaseNum == x.(int) {
						log.LoggerWContext(ctx).Debug(prettyType + "Found the ip " + reqIP.String() + "in the cache")
						_, returnedMac, _ := handler.available.GetMACIndex(uint64(x.(int)))
						if returnedMac == p.CHAddr().String() {
							log.LoggerWContext(ctx).Info("Temporarily declaring " + reqIP.String() + " as unusable")
							handler.available.ReserveIPIndex(uint64(leaseNum), FakeMac)
							// Put it back into the available IPs in 10 minutes
							go func(ctx context.Context, leaseNum int, reqIP net.IP) {
								time.Sleep(10 * time.Minute)
								log.LoggerWContext(ctx).Info("Releasing previously declined IP " + reqIP.String() + " back into the pool")
								handler.available.FreeIPIndex(uint64(leaseNum))
							}(ctx, leaseNum, reqIP)
							go func(ctx context.Context, x int, reqIP net.IP) {
								handler.hwcache.Delete(p.CHAddr().String())
							}(ctx, x.(int), reqIP)
						}
					} else {
						log.LoggerWContext(ctx).Debug(prettyType + "Found the mac in the cache for but wrong IP")
					}
				}
			}

			log.LoggerWContext(ctx).Info(prettyType + " of " + reqIP.String() + " from " + clientMac)

			return answer

		case dhcp.Decline:
			reqIP := net.IP(options[dhcp.OptionRequestedIPAddress])
			if reqIP == nil {
				reqIP = net.IP(p.CIAddr())
			}

			// Static IP ?
			if leaseNum := dhcp.IPRange(handler.start, reqIP) - 1; leaseNum >= 0 && leaseNum < handler.leaseRange {
				// Static ip address assigned ?
				if position, ok := handler.ipAssigned[p.CHAddr().String()]; ok {
					if int(position) == leaseNum {
						return answer
					}

				}
				// Remove the mac from the cache
				if x, found := handler.hwcache.Get(p.CHAddr().String()); found {
					if leaseNum == x.(int) {
						log.LoggerWContext(ctx).Debug(prettyType + "Found the ip " + reqIP.String() + "in the cache")
						_, returnedMac, _ := handler.available.GetMACIndex(uint64(x.(int)))
						if returnedMac == p.CHAddr().String() {
							log.LoggerWContext(ctx).Info("Temporarily declaring " + reqIP.String() + " as unusable")
							handler.available.ReserveIPIndex(uint64(leaseNum), FakeMac)
							// Put it back into the available IPs in 10 minutes
							go func(ctx context.Context, leaseNum int, reqIP net.IP) {
								time.Sleep(10 * time.Minute)
								log.LoggerWContext(ctx).Info("Releasing previously declined IP " + reqIP.String() + " back into the pool")
								handler.available.FreeIPIndex(uint64(leaseNum))
							}(ctx, leaseNum, reqIP)
							go func(ctx context.Context, x int, reqIP net.IP) {
								handler.hwcache.Delete(p.CHAddr().String())
							}(ctx, x.(int), reqIP)
						}
					} else {
						log.LoggerWContext(ctx).Debug(prettyType + "Found the mac in the cache for but wrong IP")
					}
				}

			}

			log.LoggerWContext(ctx).Info(prettyType + " of " + reqIP.String() + " from " + clientMac)

			return answer

		}

		answer.Iface = h.intNet
		log.LoggerWContext(ctx).Info(p.CHAddr().String() + " Nak " + sharedutils.ByteToString(p.XId()))
		answer.D = dhcp.ReplyPacket(p, dhcp.NAK, handler.ip.To4(), nil, 0, nil)
		return answer
	}
	return answer

}

func recoverName(options dhcp.Options) {
	if r := recover(); r != nil {
		fmt.Println("recovered from ", r)
		fmt.Println(errors.Wrap(r, 2).ErrorStack())
		spew.Dump(options)
	}
}
