package main

import (
	"context"
	"encoding/binary"
	"math/rand"
	"net"
	"regexp"
	"strconv"
	"strings"
	"time"

	cache "github.com/fdurand/go-cache"
	"github.com/go-errors/errors"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/filter_client"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	dhcp "github.com/krolaw/dhcp4"
)

// NodeInfo struct
type NodeInfo struct {
	Mac      string
	Status   string
	Category string
}

// connectDB connect to the database
func connectDB(configDatabase pfconfigdriver.PfConfDatabase) {
	db, err := db.DbFromConfig(ctx)
	sharedutils.CheckError(err)
	MySQLdatabase = db
}

// initiaLease fetch the database to remove already assigned ip addresses
func initiaLease(dhcpHandler *DHCPHandler, ConfNet pfconfigdriver.RessourseNetworkConf) {
	// Need to calculate the end ip because of the ip per role feature
	now := time.Now()
	endip := binary.BigEndian.Uint32(dhcpHandler.start.To4()) + uint32(dhcpHandler.leaseRange) - uint32(1)
	a := make([]byte, 4)
	binary.BigEndian.PutUint32(a, endip)
	ipend := net.IPv4(a[0], a[1], a[2], a[3])

	rows, err := MySQLdatabase.Query("select ip,mac,end_time,start_time from ip4log i where inet_aton(ip) between inet_aton(?) and inet_aton(?) and (end_time = 0 OR  end_time > NOW()) and end_time in (select MAX(end_time) from ip4log where mac = i.mac)  ORDER BY mac,end_time desc", dhcpHandler.start.String(), ipend.String())
	if err != nil {
		log.LoggerWContext(ctx).Error(err.Error())
		return
	}
	defer rows.Close()
	var (
		ipstr      string
		mac        string
		endTime    time.Time
		startTime  time.Time
		reservedIP []net.IP
		found      bool
	)
	found = false
	excludeIP := ExcludeIP(dhcpHandler, ConfNet.IpReserved)
	dhcpHandler.ipAssigned, reservedIP = AssignIP(dhcpHandler, ConfNet.IpAssigned)
	dhcpHandler.ipReserved = ConfNet.IpReserved

	for rows.Next() {
		err := rows.Scan(&ipstr, &mac, &endTime, &startTime)
		if err != nil {
			log.LoggerWContext(ctx).Error(err.Error())
			return
		}
		for _, ans := range append(excludeIP, reservedIP...) {
			if net.ParseIP(ipstr).Equal(ans) {
				found = true
				break
			}
		}
		if found == false {
			// Calculate the leasetime from the date in the database
			var leaseDuration time.Duration
			if endTime.IsZero() {
				leaseDuration = dhcpHandler.leaseDuration
			} else {
				leaseDuration = endTime.Sub(now)
			}
			ip := net.ParseIP(ipstr)

			// Calculate the position for the roaring bitmap
			position := uint32(binary.BigEndian.Uint32(ip.To4())) - uint32(binary.BigEndian.Uint32(dhcpHandler.start.To4()))
			// Remove the position in the roaming bitmap
			dhcpHandler.available.ReserveIPIndex(uint64(position), mac)
			// Add the mac in the cache
			dhcpHandler.hwcache.Set(mac, int(position), leaseDuration)
			GlobalIPCache.Set(ipstr, mac, leaseDuration)
			GlobalMacCache.Set(mac, ipstr, leaseDuration)
		}
	}
}

// InterfaceScopeFromMac detect in which scope the mac is
func InterfaceScopeFromMac(MAC string) string {
	var NetWork string
	if index, found := GlobalMacCache.Get(MAC); found {
		for _, v := range DHCPConfig.intsNet {
			v := v
			for network := range v.network {
				if v.network[network].network.Contains(net.ParseIP(index.(string))) {
					NetWork = v.network[network].network.String()
					if x, found := v.network[network].dhcpHandler.hwcache.Get(MAC); found {
						v.network[network].dhcpHandler.hwcache.Replace(MAC, x.(int), 3*time.Second)
						log.LoggerWContext(ctx).Info(MAC + " removed")
					}
				}
			}
		}
	}
	return NetWork
}

// Detect the vip on each interfaces
func (d *Interfaces) detectVIP(interfaces []string) {

	var keyConfCluster pfconfigdriver.NetInterface
	keyConfCluster.PfconfigNS = "config::Pf(CLUSTER," + pfconfigdriver.FindClusterName(ctx) + ")"

	for _, v := range interfaces {
		keyConfCluster.PfconfigHashNS = "interface " + v
		pfconfigdriver.FetchDecodeSocket(ctx, &keyConfCluster)
		// Nothing in keyConfCluster.Ip so we are not in cluster mode
		if keyConfCluster.Ip == "" {
			VIP[v] = true
			continue
		}

		if _, found := VIP[v]; !found {
			VIP[v] = false
		}

		eth, _ := net.InterfaceByName(v)
		adresses, _ := eth.Addrs()
		var found bool
		found = false
		for _, adresse := range adresses {
			IP, _, _ := net.ParseCIDR(adresse.String())
			VIPIp[v] = net.ParseIP(keyConfCluster.Ip)
			if IP.Equal(VIPIp[v]) {
				found = true
				if VIP[v] == false {
					log.LoggerWContext(ctx).Info(v + " got the VIP")
					if h, ok := intNametoInterface[v]; ok {
						go h.handleAPIReq(APIReq{Req: "initialease", NetInterface: v, NetWork: ""})
					}
					VIP[v] = true
				}
			}
		}
		if found == false {
			VIP[v] = false
		}
	}
}

// NodeInformation return the node information
func NodeInformation(ctx context.Context, target net.HardwareAddr) (r NodeInfo) {

	rows, err := MySQLdatabase.Query("SELECT mac, status, IF(ISNULL(nc.name), '', nc.name) as category FROM node LEFT JOIN node_category as nc on node.category_id = nc.category_id WHERE mac = ?", target.String())
	defer rows.Close()

	if err != nil {
		log.LoggerWContext(ctx).Crit(err.Error())
	}

	var (
		Category string
		Status   string
		Mac      string
	)
	// Set default values
	var Node = NodeInfo{Mac: target.String(), Status: "unreg", Category: "default"}

	for rows.Next() {
		err := rows.Scan(&Mac, &Status, &Category)
		if err != nil {
			log.LoggerWContext(ctx).Crit(err.Error())

		}
	}

	Node = NodeInfo{Mac: Mac, Status: Status, Category: Category}
	return Node
}

// ShuffleDNS return the dns list
func ShuffleDNS(ConfNet pfconfigdriver.RessourseNetworkConf) (r []byte) {
	if ConfNet.ClusterIPs != "" {
		if ConfNet.Dnsvip != "" {
			return []byte(net.ParseIP(ConfNet.Dnsvip).To4())
		}
		return Shuffle(ConfNet.ClusterIPs)
	}
	if ConfNet.Dnsvip != "" {
		return []byte(net.ParseIP(ConfNet.Dnsvip).To4())
	}
	return []byte(net.ParseIP(ConfNet.Dns).To4())
}

// ShuffleGateway return the gateway list
func ShuffleGateway(ConfNet pfconfigdriver.RessourseNetworkConf) (r []byte) {
	if ConfNet.NextHop != "" {
		return []byte(net.ParseIP(ConfNet.Gateway).To4())
	} else if ConfNet.ClusterIPs != "" {
		if ConfNet.Type == "inlinel2" && ConfNet.NatEnabled == "disabled" {
			return []byte(net.ParseIP(ConfNet.Gateway).To4())
		}
		return Shuffle(ConfNet.ClusterIPs)

	} else {
		return []byte(net.ParseIP(ConfNet.Gateway).To4())
	}
}

// Shuffle addresses
func Shuffle(addresses string) (r []byte) {
	var array []net.IP
	for _, adresse := range strings.Split(addresses, ",") {
		array = append(array, net.ParseIP(adresse).To4())
	}

	slice := make([]byte, 0, len(array))

	random := rand.New(rand.NewSource(time.Now().UnixNano()))
	for i := len(array) - 1; i > 0; i-- {
		j := random.Intn(i + 1)
		array[i], array[j] = array[j], array[i]
	}
	for _, element := range array {
		elem := []byte(element)
		slice = append(slice, elem...)
	}
	return slice
}

// ShuffleNetIP shuffle an array of net.IP
func ShuffleNetIP(array []net.IP, randSrc int64) (r []byte) {

	slice := make([]byte, 0, len(array))

	if randSrc == 0 {
		randSrc = time.Now().UnixNano()
	}
	random := rand.New(rand.NewSource(randSrc))
	for i := len(array) - 1; i > 0; i-- {
		j := random.Intn(i + 1)
		array[i], array[j] = array[j], array[i]
	}
	for _, element := range array {
		elem := []byte(element)
		slice = append(slice, elem...)
	}
	return slice
}

// ShuffleIP shuffle ip
func ShuffleIP(a []byte, randSrc int64) (r []byte) {

	var array []net.IP
	for len(a) != 0 {
		array = append(array, net.IPv4(a[0], a[1], a[2], a[3]).To4())
		_, a = a[0], a[4:]
	}
	return ShuffleNetIP(array, randSrc)
}

// IPsFromRange split ip range
func IPsFromRange(iPrange string) (r []net.IP, i int) {
	var iplist []net.IP
	iprange := strings.Split(iPrange, ",")
	if len(iprange) >= 1 {
		for _, rangeip := range iprange {
			ips := strings.Split(rangeip, "-")
			if len(ips) == 1 {
				iplist = append(iplist, net.ParseIP(ips[0]))
			} else {
				start := net.ParseIP(ips[0])
				end := net.ParseIP(ips[1])

				for {
					iplist = append(iplist, net.ParseIP(start.String()))
					if start.Equal(end) {
						break
					}
					sharedutils.Inc(start)
				}
			}
		}
	}
	return iplist, len(iplist)
}

// ExcludeIP remove IP from the pool
func ExcludeIP(dhcpHandler *DHCPHandler, ipRange string) []net.IP {
	excludeIPs, _ := IPsFromRange(ipRange)

	for _, excludeIP := range excludeIPs {
		if excludeIP != nil {
			// Calculate the position for the dhcp pool
			position := uint32(binary.BigEndian.Uint32(excludeIP.To4())) - uint32(binary.BigEndian.Uint32(dhcpHandler.start.To4()))

			dhcpHandler.available.ReserveIPIndex(uint64(position), FakeMac)
		}
	}
	return excludeIPs
}

// AssignIP static IP address to a mac address and remove it from the pool
func AssignIP(dhcpHandler *DHCPHandler, ipRange string) (map[string]uint32, []net.IP) {
	couple := make(map[string]uint32)
	var iplist []net.IP
	if ipRange != "" {
		rgx, _ := regexp.Compile("((?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}):((?:[0-9]{1,3}.){3}(?:[0-9]{1,3}))")
		ipRangeArray := strings.Split(ipRange, ",")
		if len(ipRangeArray) >= 1 {
			for _, rangeip := range ipRangeArray {
				result := rgx.FindStringSubmatch(rangeip)
				position := uint32(binary.BigEndian.Uint32(net.ParseIP(result[2]).To4())) - uint32(binary.BigEndian.Uint32(dhcpHandler.start.To4()))
				// Remove the position in the roaming bitmap
				dhcpHandler.available.ReserveIPIndex(uint64(position), result[1])
				couple[result[1]] = position
				iplist = append(iplist, net.ParseIP(result[2]))
			}
		}
	}
	return couple, iplist
}

// AddDevicesOptions function add options on the fly
func AddDevicesOptions(object string, leaseDuration *time.Duration, GlobalOptions map[dhcp.OptionCode][]byte) {
	x, err := decodeOptions(object)
	if err == nil {
		for key, value := range x {
			if key == dhcp.OptionIPAddressLeaseTime {
				seconds, _ := strconv.Atoi(string(value))
				*leaseDuration = time.Duration(seconds) * time.Second
				continue
			}
			GlobalOptions[key] = value
		}
	}
}

// AddPffilterDevicesOptions add options on the fly from pffilter
func AddPffilterDevicesOptions(info interface{}, GlobalOptions map[dhcp.OptionCode][]byte) error {
	var err error
	for key, value := range info.(map[string]interface{}) {
		if key == "reject" {
			err = errors.New("Rejected from pffilter")
			return err
		}
		if s, ok := value.(string); ok {
			var opcode dhcp.OptionCode
			intvalue, _ := strconv.Atoi(key)
			opcode = dhcp.OptionCode(intvalue)
			GlobalOptions[opcode] = Tlv.Tlvlist[int(opcode)].Transform.Encode(s)
		}
	}
	return nil
}

// GetFromGlobalFilterCache retreive the global option from the cache
func GetFromGlobalFilterCache(msgType string, mac string, Options map[string]string) interface{} {
	var info interface{}
	var err error
	pffilter := filter_client.NewClient()
	Filter, found := GlobalFilterCache.Get(mac + "" + msgType)
	if found && Filter != "null" {
		info = Filter
	} else {
		info, err = pffilter.FilterDhcp(msgType, map[string]interface{}{
			"mac":     mac,
			"options": Options,
		})
		if err != nil {
			GlobalFilterCache.Set(mac+""+msgType, "null", cache.DefaultExpiration)
		} else {
			GlobalFilterCache.Set(mac+""+msgType, info, cache.DefaultExpiration)
		}
	}
	return info
}

// IsIPv4 test if the ip is v4
func IsIPv4(address net.IP) bool {
	return strings.Count(address.String(), ":") < 2
}

// IsIPv6 test if the ip is v6
func IsIPv6(address net.IP) bool {
	return strings.Count(address.String(), ":") >= 2
}

// MysqlUpdateIP4Log update the ip4log table
func MysqlUpdateIP4Log(mac string, ip string, duration time.Duration) error {
	if err := MySQLdatabase.PingContext(ctx); err != nil {
		log.LoggerWContext(ctx).Error("Unable to ping database, reconnect: " + err.Error())
	}

	MAC2IP, err := MySQLdatabase.Prepare("SELECT mac, ip, start_time, end_time FROM ip4log WHERE mac = ? AND (end_time = 0 OR ( end_time + INTERVAL 30 SECOND ) > NOW()) AND tenant_id = ? ORDER BY start_time DESC LIMIT 1")
	if err != nil {
		return err
	}

	IP2MAC, err := MySQLdatabase.Prepare("SELECT mac, ip, start_time, end_time FROM ip4log WHERE ip = ? AND (end_time = 0 OR end_time > NOW()) AND tenant_id = ? ORDER BY start_time DESC")
	if err != nil {
		return err
	}

	IPClose, err := MySQLdatabase.Prepare(" UPDATE ip4log SET end_time = NOW() WHERE ip = ?")
	if err != nil {
		return err
	}

	IPInsert, err := MySQLdatabase.Prepare("INSERT INTO ip4log (mac, ip, start_time, end_time) VALUES (?, ?, NOW(), DATE_ADD(NOW(), INTERVAL ? SECOND))")
	if err != nil {
		return err
	}

	var (
		oldMAC string
		oldIP  string
	)
	err = MAC2IP.QueryRow(mac, 1).Scan(&oldIP)
	if err != nil {
		return err
	}
	err = IP2MAC.QueryRow(ip, 1).Scan(&oldMAC)
	if err != nil {
		return err
	}
	if oldMAC != mac {
		_, err = IPClose.Exec(ip)
		if err != nil {
			return err
		}
	}
	if oldIP != ip {
		_, err = IPClose.Exec(oldIP)
		if err != nil {
			return err
		}
	}
	IPInsert.Exec(mac, ip, duration.Seconds())

	return err

}

func stringInSlice(a string, list []string) bool {
	for _, b := range list {
		if b == a {
			return true
		}
	}
	return false
}

func setOptionServerIdentifier(srvIP net.IP, handlerIP net.IP) net.IP {
	if srvIP.Equal(handlerIP) || srvIP.Equal(net.IPv4zero) || srvIP.Equal(net.IPv4bcast) {
		return handlerIP
	}
	return srvIP
}
