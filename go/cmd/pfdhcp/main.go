package main

import (
	"database/sql"
	"encoding/binary"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"

	"context"
	_ "expvar"
	"net"
	"net/http"
	"strconv"
	"time"

	"net/http/pprof"
	_ "net/http/pprof"

	"github.com/coreos/go-systemd/daemon"
	"github.com/davecgh/go-spew/spew"
	"github.com/fdurand/arp"
	cache "github.com/fdurand/go-cache"
	"github.com/go-errors/errors"
	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
	dhcp "github.com/inverse-inc/dhcp4"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/timedlock"
	statsd "gopkg.in/alexcesaro/statsd.v2"
)

// Configuration constants
const (
	// FreeMac global constant
	FreeMac = "00:00:00:00:00:00"
	// FakeMac global constant
	FakeMac = "ff:ff:ff:ff:ff:ff"

	// Cache durations
	ipCacheDuration        = 5 * time.Minute
	ipCacheCleanupInterval = 10 * time.Minute
	transactionTimeout     = 1 * time.Second
	staleIPTimeout         = 10 * time.Minute
	pingResponseTimeout    = 30 * time.Second

	// Server configuration
	httpServerPort        = ":22222"
	httpServerTimeout     = 30 * time.Second
	dbPingInterval        = 5 * time.Second
	vipDetectInterval     = 3 * time.Second
	configRefreshInterval = 1 * time.Second
)

// Global variables
var (
	// DHCPConfig global var
	DHCPConfig *Interfaces

	// Cache system
	GlobalIPCache                 *cache.Cache
	GlobalMacCache                *cache.Cache
	GlobalFilterCache             *cache.Cache
	GlobalTransactionCache        *cache.Cache
	GlobalTransactionLock         *timedlock.RWLock
	RequestGlobalTransactionCache *cache.Cache

	// VIP management
	VIP   map[string]bool
	VIPIp map[string]net.IP

	// Base context
	ctx context.Context

	// Configuration
	webservices        *pfconfigdriver.PfConfWebservices
	intNametoInterface map[string]*Interface

	// Stats
	StatsdClient *statsd.Client

	// Connection pool
	dbConnPool *sql.DB
)

// initializeCaches sets up all the cache systems with consistent timeouts
func initializeCaches() {
	GlobalIPCache = cache.New(ipCacheDuration, ipCacheCleanupInterval)
	GlobalMacCache = cache.New(ipCacheDuration, ipCacheCleanupInterval)
	GlobalTransactionCache = cache.New(ipCacheDuration, ipCacheCleanupInterval)
	GlobalTransactionLock = timedlock.NewRWLock()
	RequestGlobalTransactionCache = cache.New(ipCacheDuration, ipCacheCleanupInterval)
	GlobalFilterCache = cache.New(2*time.Minute, 4*time.Minute)
}

func main() {

	// Setup graceful shutdown
	rootCtx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle interruptions
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		cancel()
	}()

	// Initialize logging
	log.SetProcessName("pfdhcp")
	ctx = log.LoggerNewContext(rootCtx)

	// Initialize ARP system with auto-refresh
	arp.AutoRefresh(30 * time.Second)

	// Configure HTTP client defaults
	http.DefaultClient.Timeout = 10 * time.Second

	// Initialize caches with consistent durations
	initializeCaches()

	// Connect to database
	configDatabase := pfconfigdriver.GetType[pfconfigdriver.PfConfDatabase](ctx)
	dbConnPool = connectDB(configDatabase)
	defer dbConnPool.Close()

	// Keep database connection alive
	go keepDatabaseAlive(ctx, dbConnPool)

	// Initialize VIP maps
	VIP = make(map[string]bool)
	VIPIp = make(map[string]net.IP)

	// Start VIP detection in background
	go detectVIPLoop(ctx, dbConnPool)

	// Initialize StatsD client
	go initStatsD(ctx)

	// Initialize DHCP configuration
	DHCPConfig = newDHCPConfig()
	DHCPConfig.readConfig(ctx, dbConnPool)
	webservices = pfconfigdriver.GetType[pfconfigdriver.PfConfWebservices](ctx)

	// Initialize worker pool for DHCP requests
	jobChan := initializeWorkerPool(dbConnPool)

	// Map interface names to interface objects
	intNametoInterface = make(map[string]*Interface)

	// Start listeners for each interface
	startNetworkListeners(ctx, jobChan)

	// Setup and start HTTP API
	router := setupAPIRoutes(ctx, dbConnPool)
	srv := createHTTPServer(router)

	// Notify systemd we're ready
	daemon.SdNotify(false, "READY=1")

	// Setup systemd watchdog
	go setupSystemdWatchdog(ctx)

	// Periodically refresh configuration
	go refreshConfigLoop(ctx)

	// Start HTTP server and wait for shutdown
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.LoggerWContext(ctx).Crit("HTTP server error: " + err.Error())
		}
	}()

	// Wait for shutdown signal
	<-rootCtx.Done()

	// Graceful shutdown
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.LoggerWContext(ctx).Error("HTTP server shutdown error: " + err.Error())
	}

	log.LoggerWContext(ctx).Info("Server gracefully stopped")

}

// Broadcast Listener
func (I *Interface) run(ctx context.Context, jobs chan job) {

	ListenAndServeIf(ctx, I, I, jobs)
}

// Unicast listener
func (I *Interface) runUnicast(ctx context.Context, jobs chan job) {

	ListenAndServeIfUnicast(ctx, I, I, jobs)
}

func (I *Interface) ServeDHCP(ctx context.Context, p dhcp.Packet, msgType dhcp.MessageType, srcIP net.Addr, srvIP net.IP, db *sql.DB) (answer Answer) {
	options := p.ParseOptions()
	answer.MAC = p.CHAddr()
	answer.SrcIP = I.Ipv4

	// ctx = log.AddToLogContext(ctx, "mac", answer.MAC.String())
	clientMac := answer.MAC.String()
	clientHostname := string(options[dhcp.OptionHostName])
	prettyType := "DHCP" + strings.ToUpper(msgType.String())

	// Get the appropriate handler and network scope
	handler, NetScope, found := I.findHandlerAndNetwork(p, answer.MAC, db)
	log.LoggerWContext(ctx).Debug(fmt.Sprintf(
		"ServeDHCP: MAC=%s giaddr=%s ciaddr=%s msgType=%s found=%v handlerIP=%s NetScope=%v",
		answer.MAC.String(), p.GIAddr().String(), p.CIAddr().String(), msgType.String(), found, func() string {
			if len(handler.ip) > 0 {
				return handler.ip.String()
			} else {
				return ""
			}
		}(), NetScope))
	if !found || len(handler.ip) == 0 {
		log.LoggerWContext(ctx).Info(fmt.Sprintf(
			"Ignored DHCP request: MAC=%s giaddr=%s ciaddr=%s msgType=%s (no handler/network found)",
			answer.MAC.String(), p.GIAddr().String(), p.CIAddr().String(), msgType.String()))
		return answer
	}

	// Check if we have the VIP or if the backend supports cluster mode
	if !VIP[I.Name] && !handler.available.Listen() {
		log.LoggerWContext(ctx).Info(fmt.Sprintf(
			"Ignored DHCP request: MAC=%s giaddr=%s ciaddr=%s msgType=%s (VIP/cluster not available)",
			answer.MAC.String(), p.GIAddr().String(), p.CIAddr().String(), msgType.String()))
		return answer
	}

	// Lock transaction to prevent duplicates
	if !I.lockTransaction(ctx, answer.MAC, msgType) {
		log.LoggerWContext(ctx).Info(fmt.Sprintf(
			"Ignored DHCP request: MAC=%s giaddr=%s ciaddr=%s msgType=%s (transaction lock)",
			answer.MAC.String(), p.GIAddr().String(), p.CIAddr().String(), msgType.String()))
		return answer
	}

	log.LoggerWContext(ctx).Debug(clientMac + " " + msgType.String() + " xID " + sharedutils.ByteToString(p.XId()))

	// Process request based on message type
	switch msgType {
	case dhcp.Discover:
		return I.handleDiscover(ctx, p, handler, answer, clientMac, clientHostname, NetScope, srvIP, msgType, db)
	case dhcp.Request, dhcp.Inform:
		return I.handleRequest(ctx, p, handler, answer, options, clientMac, clientHostname, prettyType, msgType, srvIP, NetScope, db)
	case dhcp.Release:
		return I.handleRelease(ctx, p, handler, answer, options, clientMac, clientHostname, prettyType)
	case dhcp.Decline:
		return I.handleDecline(ctx, p, handler, answer, options, clientMac, clientHostname, prettyType)
	default:
		log.LoggerWContext(ctx).Info(clientMac + " NAK " + sharedutils.ByteToString(p.XId()) + " mac=" + clientMac)
		answer.D = dhcp.ReplyPacket(p, dhcp.NAK, setOptionServerIdentifier(srvIP, handler.ip).To4(), nil, 0, nil)
		return answer
	}
}

func (I *Interface) handleDecline(ctx context.Context, p dhcp.Packet, handler DHCPHandler, answer Answer, options map[dhcp.OptionCode][]byte, clientMac string, clientHostname string, prettyType string) Answer {
	reqIP := net.IP(options[dhcp.OptionRequestedIPAddress])
	if reqIP == nil {
		reqIP = net.IP(p.CIAddr())
	}
	log.LoggerWContext(ctx).Info(prettyType + " for " + reqIP.String() + " from " + clientMac + " (" + clientHostname + ")" + " mac=" + clientMac)

	// Static IP ?
	if leaseNum := dhcp.IPRange(handler.start, reqIP) - 1; leaseNum >= 0 && leaseNum < handler.leaseRange {
		// Static ip address assigned ?
		if position, ok := handler.ipAssigned[answer.MAC.String()]; ok {
			if int(position) == leaseNum {
				return answer
			}

		}
		// Remove the mac from the cache
		if x, found := handler.hwcache.Get(answer.MAC.String()); found {
			if leaseNum == x.(int) {
				log.LoggerWContext(ctx).Debug(prettyType + " Found the ip " + reqIP.String() + " in the cache" + " mac=" + clientMac)
				_, returnedMac, _ := handler.available.GetMACIndex(uint64(x.(int)))
				if returnedMac == answer.MAC.String() {
					log.LoggerWContext(ctx).Info("Temporarily declaring " + reqIP.String() + " as unusable" + " mac=" + clientMac)
					// Remove in the cache and in the pool
					handler.hwcache.Delete(answer.MAC.String())
					// Assign the fakemac to reserve the ip
					handler.available.FreeIPIndex(uint64(leaseNum))
					handler.available.ReserveIPIndex(uint64(leaseNum), FakeMac)
					// Put it back into the available IPs in 30 seconds
					go func(leaseNum int, reqIP net.IP) {
						// Use a timer that can be interrupted by context cancellation
						timer := time.NewTimer(30 * time.Second)
						defer timer.Stop()

						select {
						case <-timer.C:
							// Timer expired normally, release the IP
							log.LoggerWContext(context.Background()).Info("Releasing previously declined IP " + reqIP.String() + " back into the pool")
							handler.available.FreeIPIndex(uint64(leaseNum))
						case <-ctx.Done():
							// Context cancelled, still release the IP to avoid leaks
							log.LoggerWContext(context.Background()).Info("Context cancelled, releasing previously declined IP " + reqIP.String() + " back into the pool")
							handler.available.FreeIPIndex(uint64(leaseNum))
						}
					}(leaseNum, reqIP)
				}
			} else {
				log.LoggerWContext(ctx).Debug(prettyType + "Found the mac in the cache for but wrong IP" + " mac=" + clientMac)
			}
		}

	}

	log.LoggerWContext(ctx).Info(prettyType + " of " + reqIP.String() + " from " + clientMac + " mac=" + clientMac)

	return answer
}

func (I *Interface) handleRelease(ctx context.Context, p dhcp.Packet, handler DHCPHandler, answer Answer, options map[dhcp.OptionCode][]byte, clientMac string, clientHostname string, prettyType string) Answer {
	reqIP := net.IP(options[dhcp.OptionRequestedIPAddress])
	if reqIP == nil {
		reqIP = net.IP(p.CIAddr())
	}
	log.LoggerWContext(ctx).Info(prettyType + " for " + reqIP.String() + " from " + clientMac + " (" + clientHostname + ")" + " mac=" + clientMac)

	if leaseNum := dhcp.IPRange(handler.start, reqIP) - 1; leaseNum >= 0 && leaseNum < handler.leaseRange {
		// Static ip address assigned ?
		if position, ok := handler.ipAssigned[answer.MAC.String()]; ok {
			if int(position) == leaseNum {
				return answer
			}

		}
		if x, found := handler.hwcache.Get(answer.MAC.String()); found {
			if leaseNum == x.(int) {
				log.LoggerWContext(ctx).Debug(prettyType + " Found the ip " + reqIP.String() + " in the cache" + " mac=" + clientMac)
				_, returnedMac, _ := handler.available.GetMACIndex(uint64(x.(int)))
				if returnedMac == answer.MAC.String() {
					log.LoggerWContext(ctx).Info("Temporarily declaring " + reqIP.String() + " as unusable" + " mac=" + clientMac)
					// Remove in the cache and in the pool
					handler.hwcache.Delete(answer.MAC.String())
					// Assign the fakemac to reserve the ip
					handler.available.FreeIPIndex(uint64(leaseNum))
					handler.available.ReserveIPIndex(uint64(leaseNum), FakeMac)
					// Put it back into the available IPs in 30 seconds
					go func(leaseNum int, reqIP net.IP) {
						// Use a timer that can be interrupted by context cancellation
						timer := time.NewTimer(30 * time.Second)
						defer timer.Stop()

						select {
						case <-timer.C:
							// Timer expired normally, release the IP
							log.LoggerWContext(context.Background()).Info("Releasing previously released IP " + reqIP.String() + " back into the pool")
							handler.available.FreeIPIndex(uint64(leaseNum))
						case <-ctx.Done():
							// Context cancelled, still release the IP to avoid leaks
							log.LoggerWContext(context.Background()).Info("Context cancelled, releasing previously released IP " + reqIP.String() + " back into the pool")
							handler.available.FreeIPIndex(uint64(leaseNum))
						}
					}(leaseNum, reqIP)
				}
			} else {
				log.LoggerWContext(ctx).Debug(prettyType + " Found the mac in the cache for but wrong IP" + " mac=" + clientMac)
			}
		}
	}

	log.LoggerWContext(ctx).Info(prettyType + " of " + reqIP.String() + " from " + clientMac + " mac=" + clientMac)

	return answer
}

func (I *Interface) handleRequest(ctx context.Context, p dhcp.Packet, handler DHCPHandler, answer Answer, options map[dhcp.OptionCode][]byte, clientMac string, clientHostname string, prettyType string, msgType dhcp.MessageType, srvIP net.IP, NetScope net.IPNet, db *sql.DB) Answer {
	reqIP := net.IP(options[dhcp.OptionRequestedIPAddress])
	if reqIP == nil {
		reqIP = net.IP(p.CIAddr())
	}

	log.LoggerWContext(ctx).Info(prettyType + " for " + reqIP.String() + " from " + clientMac + " (" + clientHostname + ")" + " mac=" + clientMac)
	cacheKey := answer.MAC.String() + " " + msgType.String() + " xID " + sharedutils.ByteToString(p.XId())

	// In the event of a DHCPREQUEST, we do not reply if we're not the server ID in the request
	serverIDBytes := options[dhcp.OptionServerIdentifier]
	if len(serverIDBytes) == 4 {
		serverID := net.IPv4(serverIDBytes[0], serverIDBytes[1], serverIDBytes[2], serverIDBytes[3])
		if !serverID.Equal(setOptionServerIdentifier(srvIP, handler.ip).To4()) {
			if !serverID.Equal(handler.ip.To4()) {
				log.LoggerWContext(ctx).Debug(fmt.Sprintf("Not replying to %s because this server didn't perform the offer (offered by %s, we are %s)", prettyType, serverID, handler.ip.To4()) + " mac=" + clientMac)
				return Answer{}
			}
		}
	}

	answer.IP = reqIP

	var Reply bool
	var Index int
	var Static bool

	Static = false
	// Valid IP
	if len(reqIP) == 4 && !reqIP.Equal(net.IPv4zero) {
		// Requested IP is in the pool ?
		if leaseNum := dhcp.IPRange(handler.start, reqIP) - 1; leaseNum >= 0 && leaseNum < handler.leaseRange {
			// Static assigned ip ?
			if position, ok := handler.ipAssigned[answer.MAC.String()]; ok {
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
				if index, found := handler.hwcache.Get(answer.MAC.String()); found {
					// Requested IP is equal to what we have in the cache ?

					if dhcp.IPAdd(handler.start, index.(int)).Equal(reqIP) {
						id, err := GlobalTransactionLock.Lock()
						if err != nil {
							log.LoggerWContext(ctx).Error("Failed to acquire transaction lock: " + err.Error())
							Reply = false
							return answer
						}
						if _, found = RequestGlobalTransactionCache.Get(cacheKey); found {
							log.LoggerWContext(ctx).Debug("Not answering to REQUEST. Already processed" + " mac=" + clientMac)
							GlobalTransactionLock.Unlock(id)
							Reply = false
							return answer
						}
						RequestGlobalTransactionCache.Set(cacheKey, 1, time.Duration(1)*time.Second)
						GlobalTransactionLock.Unlock(id)
						Reply = true
						Index = index.(int) // So remove the ip from the cache
					} else {
						Reply = false
						log.LoggerWContext(ctx).Info(answer.MAC.String() + " Asked for an IP " + reqIP.String() + " that hasnt been assigned by Offer " + dhcp.IPAdd(handler.start, index.(int)).String() + " xID " + sharedutils.ByteToString(p.XId()) + " mac=" + clientMac)
						if index, found = handler.xid.Get(fmt.Sprintf("%d", (binary.BigEndian.Uint32(p.XId())))); found {
							if index.(int) == 1 {
								handler.hwcache.Delete(answer.MAC.String())
							}
						}
					}
				} else {
					// Not in the cache so we don't reply
					log.LoggerWContext(ctx).Debug(fmt.Sprintf("Not replying to %s because this server didn't perform the offer", prettyType) + " mac=" + clientMac)
					return Answer{}
				}
			}
		}

		if Reply {

			var info interface{}

			var GlobalOptions dhcp.Options
			var options = make(map[dhcp.OptionCode][]byte)
			for key, value := range handler.options {
				if key == dhcp.OptionDomainNameServer || key == dhcp.OptionRouter {
					options[key] = ShuffleIP(ctx, value)
				} else {
					options[key] = value
				}
			}
			GlobalOptions = options
			leaseDuration := handler.leaseDuration
			// Add network options
			AddDevicesOptions(NetScope.IP.String(), &leaseDuration, GlobalOptions, db)
			// Add device options
			AddDevicesOptions(answer.MAC.String(), &leaseDuration, GlobalOptions, db)
			info = GetFromGlobalFilterCache(msgType.String(), answer.MAC.String(), I.getOptions(p))
			// Add options on the fly from pffilter
			reject := AddPffilterDevicesOptions(info, GlobalOptions)
			if _, ok := GlobalOptions[dhcp.OptionIPAddressLeaseTime]; ok {
				leaseDuration = 0
			}

			if reject != nil {
				log.LoggerWContext(ctx).Info("DHCPNAK on " + reqIP.String() + " to " + clientMac + " mac=" + clientMac)
				answer.D = dhcp.ReplyPacket(p, dhcp.NAK, setOptionServerIdentifier(srvIP, handler.ip).To4(), nil, 0, nil)
				return answer
			}
			answer.D = dhcp.ReplyPacket(p, dhcp.ACK, setOptionServerIdentifier(srvIP, handler.ip).To4(), reqIP, leaseDuration,
				GlobalOptions.SelectOrderOrAll(options[dhcp.OptionParameterRequestList]))
			var cacheDuration time.Duration
			if leaseDuration < time.Duration(60)*time.Second {
				cacheDuration = time.Duration(120) * time.Second
			} else {
				cacheDuration = leaseDuration + (time.Duration(60) * time.Second)
			}

			// Update Global Caches
			GlobalIPCache.Set(reqIP.String(), answer.MAC.String(), cacheDuration)
			GlobalMacCache.Set(answer.MAC.String(), reqIP.String(), cacheDuration)
			err := MysqlUpdateIP4Log(ctx, answer.MAC.String(), reqIP.String(), cacheDuration, db)
			if err != nil {
				log.LoggerWContext(ctx).Info(err.Error() + " mac=" + clientMac)
			}
			log.LoggerWContext(ctx).Info("DHCPACK on " + reqIP.String() + " to " + clientMac + " (" + clientHostname + ")" + " mac=" + clientMac)

			handler.hwcache.Set(answer.MAC.String(), Index, cacheDuration)
			handler.available.ReserveIPIndex(uint64(Index), answer.MAC.String())

		} else {
			log.LoggerWContext(ctx).Info("DHCPNAK on " + reqIP.String() + " to " + clientMac + " mac=" + clientMac)
			answer.D = dhcp.ReplyPacket(p, dhcp.NAK, setOptionServerIdentifier(srvIP, handler.ip).To4(), nil, 0, nil)
		}
		return answer
	}
	log.LoggerWContext(ctx).Info("DHCPNAK on " + reqIP.String() + " to " + clientMac + " mac=" + clientMac)
	answer.D = dhcp.ReplyPacket(p, dhcp.NAK, setOptionServerIdentifier(srvIP, handler.ip).To4(), nil, 0, nil)
	return answer
}

func (I *Interface) getOptions(p dhcp.Packet) map[string]string {
	options := p.ParseOptions()
	var Options map[string]string
	Options = make(map[string]string)
	for option, value := range options {
		key := []byte(option.String())
		key[0] = key[0] | ('a' - 'A')
		if _, ok := Tlv.Tlvlist[int(option)]; ok {
			Options[string(key)] = Tlv.Tlvlist[int(option)].Transform.String(value)
		}
	}
	return Options
}

func (I *Interface) handleDiscover(ctx context.Context, p dhcp.Packet, handler DHCPHandler, answer Answer, clientMac string, clientHostname string, NetScope net.IPNet, srvIP net.IP, msgType dhcp.MessageType, db *sql.DB) Answer {
	firstTry := true
	log.LoggerWContext(ctx).Info("DHCPDISCOVER from " + clientMac + " (" + clientHostname + ")" + " mac=" + clientMac)
	var free int
	free = -1
	// Static assign IP address ?
	if position, ok := handler.ipAssigned[answer.MAC.String()]; ok {
		free = int(position)
		log.LoggerWContext(ctx).Debug("Static IP found" + " mac=" + clientMac)
		goto reply
	}
	// Search in the cache if the mac address already get assigned
	log.LoggerWContext(ctx).Debug("Search in the cache if an IP has already been assigned" + " mac=" + clientMac)
	if x, found := handler.hwcache.Get(answer.MAC.String()); found {
		log.LoggerWContext(ctx).Debug("Found in the cache that a IP has already been assigned" + " mac=" + clientMac)
		// Test if we find the mac address at the index
		_, returnedMac, err := handler.available.GetMACIndex(uint64(x.(int)))
		if err != nil {
			log.LoggerWContext(ctx).Error(err.Error() + " mac=" + clientMac)
		}
		if returnedMac == answer.MAC.String() {
			free = x.(int)
		} else if returnedMac == FreeMac {
			// The index is free use it
			// Remove the entry in the cache for this mac address since the ip is free but not assigned to this mac
			handler.hwcache.Delete(answer.MAC.String())
			// Reserve the ip
			returnedMac, err = handler.available.ReserveIPIndex(uint64(x.(int)), answer.MAC.String())
			if err != nil {
				log.LoggerWContext(ctx).Error(err.Error() + " mac=" + clientMac)
			}
			if err == nil && returnedMac == answer.MAC.String() {
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
		err = handler.hwcache.Replace(answer.MAC.String(), free, time.Duration(5)*time.Second)
		if err != nil {
			return answer
		}
		goto reply
	}
	log.LoggerWContext(ctx).Debug("Not Found in the cache that a IP has already been assigned" + " mac=" + clientMac)
retry:
	// Search for the next available ip in the pool
	log.LoggerWContext(ctx).Debug("Search if there is still available IP in the pool" + " mac=" + clientMac)
	if handler.available.FreeIPsRemaining() > 0 {
		log.LoggerWContext(ctx).Debug("Still available IP in the pool" + " mac=" + clientMac)
		var element uint32
		// Check if the device request a specific ip
		if p.ParseOptions()[50] != nil && firstTry {
			log.LoggerWContext(ctx).Debug("Attempting to use the IP requested by the device" + " mac=" + clientMac)
			element = uint32(binary.BigEndian.Uint32(p.ParseOptions()[50])) - uint32(binary.BigEndian.Uint32(handler.start.To4()))
			// Test if we find the mac address at the index
			_, returnedMac, err := handler.available.GetMACIndex(uint64(element))
			if err != nil {
				log.LoggerWContext(ctx).Error(err.Error() + " mac=" + clientMac)
			}
			if err == nil && returnedMac == answer.MAC.String() {
				log.LoggerWContext(ctx).Debug("The IP asked by the device is available in the pool" + " mac=" + clientMac)
				free = int(element)
			} else if err == nil && returnedMac == FreeMac {
				log.LoggerWContext(ctx).Debug("The IP asked by the device is available in the pool" + " mac=" + clientMac)
				// The ip is free use it
				returnedMac, err = handler.available.ReserveIPIndex(uint64(element), answer.MAC.String())
				// Reserve the ip
				if err != nil {
					log.LoggerWContext(ctx).Error(err.Error())
					// The ip is not available
					firstTry = false
					goto retry
				}
				if err == nil && returnedMac == answer.MAC.String() {
					log.LoggerWContext(ctx).Debug("The IP asked by the device is available in the pool" + " mac=" + clientMac)
					free = int(element)
				}
			} else {
				// The ip is not available
				firstTry = false
				goto retry
			}
		}
		// If we still haven't found an IP address to offer, we get the next one
		if free == -1 {
			log.LoggerWContext(ctx).Debug("Grabbing next available IP" + " mac=" + clientMac)
			freeu64, _, err := handler.available.GetFreeIPIndex(answer.MAC.String())
			if err != nil {
				log.LoggerWContext(ctx).Error(err.Error() + " mac=" + clientMac)
				return answer
			}
			free = int(freeu64)
		}
		// Lock it
		handler.hwcache.Set(answer.MAC.String(), free, time.Duration(5)*time.Second)
		handler.xid.Set(sharedutils.ByteToString(p.XId()), 0, time.Duration(5)*time.Second)
		var inarp bool
		// Ping the ip address
		inarp = false
		// Layer 2 test (arp cache)
		if handler.layer2 {
			mac := arp.Search(dhcp.IPAdd(handler.start, free).String())
			if mac != "" && mac != FreeMac {
				if answer.MAC.String() != mac {
					log.LoggerWContext(ctx).Info(answer.MAC.String() + " in arp table Ip " + dhcp.IPAdd(handler.start, free).String() + " is already own by " + mac + " mac=" + clientMac)
					inarp = true
				}
			}
		}
		// Layer 3 Test
		pingreply := sharedutils.Ping(setOptionServerIdentifier(srvIP, handler.ip).To4(), dhcp.IPAdd(handler.start, free), I.Name, 1)
		if pingreply || inarp {
			// Found in the arp cache or able to ping it
			ipaddr := dhcp.IPAdd(handler.start, free)
			log.LoggerWContext(ctx).Info(answer.MAC.String() + " Ip " + ipaddr.String() + " already in use, trying next" + " mac=" + clientMac)
			// Added back in the pool since it's not the dhcp server who gave it
			handler.hwcache.Delete(answer.MAC.String())

			firstTry = false

			log.LoggerWContext(ctx).Info("Temporarily declaring " + ipaddr.String() + " as unusable" + " mac=" + clientMac)
			// Reserve with a fake mac
			handler.available.ReserveIPIndex(uint64(free), FakeMac)
			// Put it back into the available IPs in 10 minutes
			go func(free int, ipaddr net.IP) {
				// Use a timer that can be interrupted by context cancellation
				timer := time.NewTimer(10 * time.Minute)
				defer timer.Stop()

				select {
				case <-timer.C:
					// Timer expired normally, release the IP
					log.LoggerWContext(context.Background()).Info("Releasing previously pingable IP " + ipaddr.String() + " back into the pool")
					handler.available.FreeIPIndex(uint64(free))
				case <-ctx.Done():
					// Context cancelled, still release the IP to avoid leaks
					log.LoggerWContext(context.Background()).Info("Context cancelled, releasing previously pingable IP " + ipaddr.String() + " back into the pool")
					handler.available.FreeIPIndex(uint64(free))
				}
			}(free, ipaddr)
			free = -1
			goto retry
		}
		// 5 seconds to send a request
		handler.hwcache.Set(answer.MAC.String(), free, time.Duration(5)*time.Second)
		handler.xid.Replace(sharedutils.ByteToString(p.XId()), 1, time.Duration(5)*time.Second)
	} else {
		log.LoggerWContext(ctx).Info(answer.MAC.String() + " Nak No space left in the pool " + " mac=" + clientMac)
		return answer
	}

	// Prepare the reply
reply:

	var info interface{}
	var err error

	answer.IP = dhcp.IPAdd(handler.start, free)
	answer.SrcIP = I.Ipv4
	// Add options on the fly
	var GlobalOptions dhcp.Options
	var options = make(map[dhcp.OptionCode][]byte)
	for key, value := range handler.options {
		if key == dhcp.OptionDomainNameServer || key == dhcp.OptionRouter {
			options[key] = ShuffleIP(ctx, value)
		} else {
			options[key] = value
		}
	}
	GlobalOptions = options
	leaseDuration := handler.leaseDuration

	// Add network options on the fly
	x, err := decodeOptions(ctx, NetScope.IP.String(), db)
	if err == nil {
		for key, value := range x {
			if key == dhcp.OptionIPAddressLeaseTime {
				seconds, _ := strconv.Atoi(string(value))
				leaseDuration = time.Duration(seconds) * time.Second
				continue
			}
			GlobalOptions[key] = value
		}
	}

	info = GetFromGlobalFilterCache(msgType.String(), answer.MAC.String(), I.getOptions(p))

	// Add options on the fly from pffilter
	reject := AddPffilterDevicesOptions(info, GlobalOptions)

	if reject != nil {
		log.LoggerWContext(ctx).Info("DHCPNAK on to " + clientMac + " mac=" + clientMac)
		answer.D = dhcp.ReplyPacket(p, dhcp.NAK, setOptionServerIdentifier(srvIP, handler.ip).To4(), nil, 0, nil)
		return answer
	}
	if _, ok := GlobalOptions[dhcp.OptionIPAddressLeaseTime]; ok {
		leaseDuration = 0
	}
	// Add device (mac) options on the fly
	x, err = decodeOptions(ctx, answer.MAC.String(), db)
	if err == nil {
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
	answer.D = dhcp.ReplyPacket(p, dhcp.Offer, setOptionServerIdentifier(srvIP, handler.ip).To4(), answer.IP, leaseDuration,
		GlobalOptions.SelectOrderOrAll(options[dhcp.OptionParameterRequestList]))

	return answer
}

// lockTransaction locks the transaction for a specific MAC address and message type
func (I *Interface) lockTransaction(ctx context.Context, mac net.HardwareAddr, msgType dhcp.MessageType) bool {
	cacheKey := mac.String() + " " + msgType.String()
	id, err := GlobalTransactionLock.Lock()
	if err != nil {
		log.LoggerWContext(ctx).Error("Failed to acquire transaction lock: " + err.Error())
		return false
	}
	if _, found := GlobalTransactionCache.Get(cacheKey); found {
		log.LoggerWContext(ctx).Debug("Not answering to packet. Already in progress")
		GlobalTransactionLock.Unlock(id)
		return false
	}
	GlobalTransactionCache.Set(cacheKey, 3, time.Duration(1)*time.Second)
	GlobalTransactionLock.Unlock(id)
	return true
}

// findHandlerAndNetwork finds the appropriate handler and network scope for the given packet
func (I *Interface) findHandlerAndNetwork(p dhcp.Packet, mac net.HardwareAddr, db *sql.DB) (handler DHCPHandler, NetScope net.IPNet, found bool) {
	var NodeCache *cache.Cache
	NodeCache = cache.New(3*time.Second, 5*time.Second)
	var node NodeInfo
	for _, v := range I.network {
		// Check if the handler is for layer 2 and if the packet is from the same network
		if v.dhcpHandler.layer2 && (p.GIAddr().Equal(net.IPv4zero) || v.network.Contains(p.CIAddr())) {
			if v.splittednet == true {

				if x, found := NodeCache.Get(p.CHAddr().String()); found {
					node = x.(NodeInfo)
				} else {
					node = NodeInformation(ctx, p.CHAddr(), db)
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
					break
				}
				continue
			} else {
				handler = *v.dhcpHandler
				NetScope = v.network
				found = true
				break
			}
		}
		// Check if the packet is from the same network for layer 3
		if p.GIAddr().Equal(net.IPv4zero) && v.network.Contains(p.CIAddr()) {
			handler = *v.dhcpHandler
			NetScope = v.network
			found = true
			break
		}
		if (!p.GIAddr().Equal(net.IPv4zero) && v.network.Contains(p.GIAddr())) || v.network.Contains(p.CIAddr()) {
			handler = *v.dhcpHandler
			NetScope = v.network
			found = true
			break
		}
	}
	return handler, NetScope, found
}

func recoverName(options dhcp.Options) {
	if r := recover(); r != nil {
		fmt.Println("recovered from ", r)
		fmt.Println(errors.Wrap(r, 2).ErrorStack())
		spew.Dump(options)
	}
}

// keepDatabaseAlive pings the database periodically to maintain connection
func keepDatabaseAlive(ctx context.Context, db *sql.DB) {
	ticker := time.NewTicker(dbPingInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := db.PingContext(ctx); err != nil {
				log.LoggerWContext(ctx).Error("Unable to ping DB: " + err.Error())
			} else {
				log.LoggerWContext(ctx).Debug("Pinged DB")
			}
		}
	}
}

// detectVIPLoop periodically checks for VIP status on interfaces
func detectVIPLoop(ctx context.Context, db *sql.DB) {
	ticker := time.NewTicker(vipDetectInterval)
	defer ticker.Stop()

	var DHCPinterfaces pfconfigdriver.DHCPInts
	pfconfigdriver.FetchDecodeSocket(ctx, &DHCPinterfaces)
	var interfaces pfconfigdriver.ListenInts
	pfconfigdriver.FetchDecodeSocket(ctx, &interfaces)

	var intDhcp []string
	for _, vi := range DHCPinterfaces.Element {
		for key, dhcpint := range vi.(map[string]interface{}) {
			if key == "int" {
				intDhcp = append(intDhcp, dhcpint.(string))
			}
		}
	}
	var CardNet []*net.Interface

	NetCard := sharedutils.RemoveDuplicates(append(interfaces.Element, intDhcp...))

	for _, v := range NetCard {
		eth, err := net.InterfaceByName(v)
		if err != nil {
			log.LoggerWContext(ctx).Error("Unable to get interface " + v + ": " + err.Error())
			continue
		}
		CardNet = append(CardNet, eth)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			DHCPConfig.detectVIP(ctx, CardNet, db)
		}
	}
}

// initStatsD initializes the StatsD client
func initStatsD(ctx context.Context) {
	var err error

	for {
		select {
		case <-ctx.Done():
			return
		default:
			var keyConfAdvanced pfconfigdriver.PfConfAdvanced
			keyConfAdvanced.PfconfigNS = "config::Pf"
			keyConfAdvanced.PfconfigHostnameOverlay = "yes"
			pfconfigdriver.FetchDecodeSocket(ctx, &keyConfAdvanced)
			options := statsd.Address("localhost:" + keyConfAdvanced.StatsdListenPort)

			StatsdClient, err = statsd.New(options)
			if err != nil {
				log.LoggerWContext(ctx).Error("Error while creating statsd client: " + err.Error())
				time.Sleep(1 * time.Second)
				continue
			}

			return // Successfully connected
		}
	}
}

// initializeWorkerPool creates a worker pool for processing DHCP requests
func initializeWorkerPool(db *sql.DB) chan job {
	maxQueueSize := 100
	maxWorkers := 100

	// Create job channel
	jobs := make(chan job, maxQueueSize)

	// Create workers
	for i := 1; i <= maxWorkers; i++ {
		go func(id int) {
			for j := range jobs {
				j.db = db
				doWork(id, j)
			}
		}(i)
	}

	return jobs
}

// startNetworkListeners starts all the network listeners for DHCP
func startNetworkListeners(ctx context.Context, jobs chan job) {
	var wg sync.WaitGroup

	// Start unicast listeners
	for _, v := range DHCPConfig.intsNet {
		v := v
		intNametoInterface[v.Name] = &v

		wg.Add(1)
		go func() {
			defer wg.Done()
			v.runUnicast(ctx, jobs)
		}()
	}

	// Start broadcast listeners
	for _, v := range DHCPConfig.intsNet {
		v := v
		wg.Add(1)
		go func() {
			defer wg.Done()
			v.run(ctx, jobs)
		}()
	}
}

// setupAPIRoutes configures the HTTP API routes
func setupAPIRoutes(ctx context.Context, db *sql.DB) *mux.Router {
	api := &API{DB: db, Ctx: ctx}
	router := mux.NewRouter()

	// API endpoints
	router.HandleFunc("/api/v1/dhcp/mac/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}", api.handleMac2Ip).Methods("GET")
	router.HandleFunc("/api/v1/dhcp/mac/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}", api.handleReleaseIP).Methods("DELETE")
	router.HandleFunc("/api/v1/dhcp/ip/{ip:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}", api.handleIP2Mac).Methods("GET")
	router.HandleFunc("/api/v1/dhcp/stats", api.handleAllStats).Methods("GET")
	router.HandleFunc("/api/v1/dhcp/stats/{int:.*}/{network:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}", api.handleStats).Methods("GET")
	router.HandleFunc("/api/v1/dhcp/stats/{int:.*}", api.handleStats).Methods("GET")
	router.HandleFunc("/api/v1/dhcp/debug/{int:.*}/{role:(?:[^/]*)}", api.handleDebug).Methods("GET")
	router.HandleFunc("/api/v1/dhcp/detect_duplicates/{int:.*}", api.handleDuplicates).Methods("GET")
	router.HandleFunc("/api/v1/dhcp/options/network/{network:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}", api.handleOverrideNetworkOptions).Methods("POST")
	router.HandleFunc("/api/v1/dhcp/options/network/{network:(?:[0-9]{1,3}.){3}(?:[0-9]{1,3})}", api.handleRemoveNetworkOptions).Methods("DELETE")
	router.HandleFunc("/api/v1/dhcp/options/mac/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}", api.handleOverrideOptions).Methods("POST")
	router.HandleFunc("/api/v1/dhcp/options/mac/{mac:(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}}", api.handleRemoveOptions).Methods("DELETE")

	// Register pprof handlers with your router
	router.HandleFunc("/debug/pprof/", pprof.Index)
	router.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
	router.HandleFunc("/debug/pprof/profile", pprof.Profile)
	router.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
	router.HandleFunc("/debug/pprof/trace", pprof.Trace)

	// These paths are for the various profile types
	router.Handle("/debug/pprof/goroutine", pprof.Handler("goroutine"))
	router.Handle("/debug/pprof/heap", pprof.Handler("heap"))
	router.Handle("/debug/pprof/threadcreate", pprof.Handler("threadcreate"))
	router.Handle("/debug/pprof/block", pprof.Handler("block"))
	router.Handle("/debug/pprof/mutex", pprof.Handler("mutex"))

	return router
}

// createHTTPServer creates an HTTP server with proper timeouts
func createHTTPServer(router *mux.Router) *http.Server {
	return &http.Server{
		Addr:         httpServerPort,
		Handler:      router,
		ReadTimeout:  httpServerTimeout,
		WriteTimeout: httpServerTimeout,
		IdleTimeout:  httpServerTimeout,
	}
}

// setupSystemdWatchdog configures systemd watchdog reporting
func setupSystemdWatchdog(ctx context.Context) {
	interval, err := daemon.SdWatchdogEnabled(false)
	if err != nil || interval == 0 {
		return
	}

	cli := &http.Client{
		Timeout: 5 * time.Second,
	}

	ticker := time.NewTicker(interval / 3)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			req, err := http.NewRequestWithContext(ctx, "GET", "http://127.0.0.1:22222", nil)
			if err != nil {
				log.LoggerWContext(ctx).Error(err.Error())
				continue
			}

			resp, err := cli.Do(req)
			if err != nil {
				log.LoggerWContext(ctx).Error(err.Error())
				continue
			}

			daemon.SdNotify(false, "WATCHDOG=1")
			resp.Body.Close()
		}
	}
}

// refreshConfigLoop periodically refreshes the configuration
func refreshConfigLoop(ctx context.Context) {
	ticker := time.NewTicker(configRefreshInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			pfconfigdriver.PfConfigStorePool.Refresh(ctx)
		}
	}
}
