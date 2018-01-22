package main

import (
	"context"
	"crypto/tls"
	"database/sql"
	"fmt"
	"io"
	"net"
	"net/http"
	"regexp"

	ipset "github.com/fdurand/go-ipset"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

var body io.Reader

type pfIPSET struct {
	Network map[*net.IPNet]string
	ListALL []ipset.IPSet
}

// Detect the vip on each interfaces
func detectMembers() []net.IP {

	var keyConfCluster pfconfigdriver.PfconfigKeys
	keyConfCluster.PfconfigNS = "resource::cluster_hosts_ip"

	// keyConfCluster.PfconfigHashNS = "interface " + v
	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfCluster)
	var members []net.IP
	for _, key := range keyConfCluster.Keys {
		var ConfNet pfconfigdriver.PfClusterIp
		ConfNet.PfconfigHashNS = key

		pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)

		IP := net.ParseIP(ConfNet.Ip)
		var present bool

		ifaces, _ := net.Interfaces()
		for _, netInterface := range ifaces {
			addrs, _ := netInterface.Addrs()
			for _, UnicastAddr := range addrs {
				IPE, _, _ := net.ParseCIDR(UnicastAddr.String())
				if IP.Equal(IPE) {
					present = true
				}
			}
		}
		if present == false {
			members = append(members, IP)
		}
	}
	return members
}

func updateClusterL2(Ip string, Mac string, Network string, Type string, Catid string) {
	for _, member := range detectMembers() {
		err := post("https://"+member.String()+":22223/ipsetmarklayer2/"+Network+"/"+Type+"/"+Catid+"/"+Ip+"/"+Mac+"/1", body)
		fmt.Println("Updated " + member.String())
		if err != nil {
			fmt.Println("Not able to contact " + member.String())
		}
	}
}

func updateClusterL3(Ip string, Network string, Type string, Catid string) {
	for _, member := range detectMembers() {
		err := post("https://"+member.String()+":22223/ipsetmarklayer3/"+Network+"/"+Type+"/"+Catid+"/"+Ip+"/1", body)
		if err != nil {
			fmt.Println("Not able to contact " + member.String())
		}
	}
}

func updateClusterUnmarkMac(Mac string) {
	for _, member := range detectMembers() {
		err := post("https://"+member.String()+":22223/ipsetunmarkmac/"+Mac+"/1", body)
		if err != nil {
			fmt.Println("Not able to contact " + member.String())
		}
	}
}

func updateClusterUnmarkIp(Ip string) {
	for _, member := range detectMembers() {

		err := post("https://"+member.String()+":22223/ipsetunmarkip/"+Ip+"/1", body)
		if err != nil {
			fmt.Println("Not able to contact " + member.String())
		}
	}
}

func updateClusterMarkIpL3(Ip string, Network string, Catid string) {
	for _, member := range detectMembers() {
		err := post("https://"+member.String()+":22223/ipsetmarkiplayer3/"+Network+"/"+Catid+"/"+Ip+"/1", body)
		if err != nil {
			fmt.Println("Not able to contact " + member.String())
		}
	}
}
func updateClusterMarkIpL2(Ip string, Network string, Catid string) {
	for _, member := range detectMembers() {
		err := post("https://"+member.String()+":22223/ipsetmarkiplayer2/"+Network+"/"+Catid+"/"+Ip+"/1", body)
		if err != nil {
			fmt.Println("Not able to contact " + member.String())
		}
	}
}

func updateClusterPassthrough(Ip string, Port string) {
	for _, member := range detectMembers() {
		err := post("https://"+member.String()+":22223/ipsetpassthrough/"+Ip+"/"+Port+"/1", body)
		fmt.Println("Updated " + member.String())
		if err != nil {
			fmt.Println("Not able to contact " + member.String())
		}
	}
}

func updateClusterPassthroughIsol(Ip string, Port string) {
	for _, member := range detectMembers() {
		err := post("https://"+member.String()+":22223/ipsetpassthroughisolation/"+Ip+"/"+Port+"/1", body)
		fmt.Println("Updated " + member.String())
		if err != nil {
			fmt.Println("Not able to contact " + member.String())
		}
	}
}

func (IPSET *pfIPSET) mac2ip(Mac string, Set string) []string {
	r := "((?:[0-9]{1,3}.){3}(?:[0-9]{1,3}))," + Mac
	rgx := regexp.MustCompile(r)

	var Ips []string
	for _, v := range IPSET.ListALL {
		if v.Name == Set {
			for _, u := range v.Members {

				if rgx.Match([]byte(u.Elem)) {
					result := rgx.FindStringSubmatch(u.Elem)

					Ips = append(Ips, result[1])
				}
			}
		}
	}
	return Ips
}

// readWebservicesConfig read pfconfig webservices configuration
func readWebservicesConfig() pfconfigdriver.PfConfWebservices {
	var webservices pfconfigdriver.PfConfWebservices
	webservices.PfconfigNS = "config::Pf"
	webservices.PfconfigMethod = "hash_element"
	webservices.PfconfigHashNS = "webservices"

	pfconfigdriver.FetchDecodeSocket(ctx, &webservices)
	return webservices
}

func post(url string, body io.Reader) error {
	req, err := http.NewRequest("POST", url, body)
	req.SetBasicAuth(webservices.User, webservices.Pass)
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	req.Header.Set("Content-Type", "application/json")
	cli := &http.Client{Transport: tr}
	_, err = cli.Do(req)
	return err
}

// connectDB connect to the database
func connectDB(configDatabase pfconfigdriver.PfconfigDatabase, db *sql.DB) {
	database, _ = sql.Open("mysql", configDatabase.DBUser+":"+configDatabase.DBPassword+"@tcp("+configDatabase.DBHost+":"+configDatabase.DBPort+")/"+configDatabase.DBName+"?parseTime=true")
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

// initIPSet fetch the database to remove already assigned ip addresses
func (IPSET *pfIPSET) initIPSet() {
	IPSET.ListALL, _ = ipset.ListAll()
	rows, err := database.Query("select distinct n.mac, i.ip, n.category_id from node as n left join locationlog as l on n.mac=l.mac left join ip4log as i on n.mac=i.mac where l.connection_type = \"inline\" and n.status=\"reg\" and n.mac=i.mac and i.end_time > NOW()")
	if err != nil {
		// Log here
		fmt.Println(err)
		return
	}
	defer rows.Close()
	var (
		ipstr string
		mac   string
		catID string
	)
	for rows.Next() {
		err := rows.Scan(&mac, &ipstr, &catID)
		if err != nil {
			// Log here
			fmt.Println(err)
			return
		}
		for k, v := range IPSET.Network {
			if k.Contains(net.ParseIP(ipstr)) {
				if v == "inlinel2" {
					IPSET.IPSEThandleLayer2(ipstr, mac, k.IP.String(), "Reg", catID)
					IPSET.IPSEThandleMarkIpL2(ipstr, k.IP.String(), catID)
				}
				if v == "inlinel3" {
					IPSET.IPSEThandleLayer3(ipstr, k.IP.String(), "Reg", catID)
					IPSET.IPSEThandleMarkIpL3(ipstr, k.IP.String(), catID)
				}
				break
			}
		}
	}
}

// detectType of each network
func (IPSET *pfIPSET) detectType() error {
	IPSET.ListALL, _ = ipset.ListAll()
	var ctx = context.Background()
	var NetIndex net.IPNet
	IPSET.Network = make(map[*net.IPNet]string)

	var interfaces pfconfigdriver.ListenInts
	pfconfigdriver.FetchDecodeSocket(ctx, &interfaces)

	var keyConfNet pfconfigdriver.PfconfigKeys
	keyConfNet.PfconfigNS = "config::Network"
	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfNet)

	var keyConfCluster pfconfigdriver.NetInterface
	keyConfCluster.PfconfigNS = "config::Pf(CLUSTER)"

	for _, v := range interfaces.Element {

		keyConfCluster.PfconfigHashNS = "interface " + v
		pfconfigdriver.FetchDecodeSocket(ctx, &keyConfCluster)
		// Nothing in keyConfCluster.Ip so we are not in cluster mode

		eth, _ := net.InterfaceByName(v)
		adresses, _ := eth.Addrs()
		for _, adresse := range adresses {

			var NetIP *net.IPNet
			var IP net.IP
			IP, NetIP, _ = net.ParseCIDR(adresse.String())
			if IP.To4() == nil {
				continue
			}
			a, b := NetIP.Mask.Size()
			if a == b {
				continue
			}

			for _, key := range keyConfNet.Keys {
				var ConfNet pfconfigdriver.NetworkConf
				ConfNet.PfconfigHashNS = key
				pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)
				if (NetIP.Contains(net.ParseIP(ConfNet.DhcpStart)) && NetIP.Contains(net.ParseIP(ConfNet.DhcpEnd))) || NetIP.Contains(net.ParseIP(ConfNet.NextHop)) {
					NetIndex.Mask = net.IPMask(net.ParseIP(ConfNet.Netmask))
					NetIndex.IP = net.ParseIP(key)
					Index := NetIndex
					IPSET.Network[&Index] = ConfNet.Type
				}
				// if ConfNet.RegNetwork != "" {
				// 	IP2, NetIP2, _ := net.ParseCIDR(ConfNet.RegNetwork)
				// 	if NetIP.Contains(IP2) {
				// 		IPSET.Network[NetIP2] = ConfNet.Type
				// 	}
				// }
			}
		}
	}
	return nil
}
