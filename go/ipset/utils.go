package main

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"regexp"

	ipset "github.com/digineo/go-ipset"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

var body io.Reader

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
		_, err := http.Post("http://"+member.String()+":22223/ipsetmarklayer2/"+Network+"/"+Type+"/"+Catid+"/"+Ip+"/"+Mac+"/1", "application/json", body)
		fmt.Println("Updated " + member.String())
		if err != nil {
			fmt.Println("Not able to contact " + member.String())
		}
	}
}

func updateClusterL3(Ip string, Network string, Type string, Catid string) {
	for _, member := range detectMembers() {
		_, err := http.Post("http://"+member.String()+":22223/ipsetmarklayer3/"+Network+"/"+Type+"/"+Catid+"/"+Ip+"/1", "application/json", body)
		if err != nil {
			fmt.Println("Not able to contact " + member.String())
		}
	}
}

func updateClusterUnmarkMac(Mac string) {
	for _, member := range detectMembers() {
		_, err := http.Post("http://"+member.String()+":22223/ipsetunmarkmac/"+Mac+"/1", "application/json", body)
		if err != nil {
			fmt.Println("Not able to contact " + member.String())
		}
	}
}

func updateClusterUnmarkIp(Ip string) {
	for _, member := range detectMembers() {

		_, err := http.Post("http://"+member.String()+":22223/ipsetunmarkip/"+Ip+"/1", "application/json", body)
		if err != nil {
			fmt.Println("Not able to contact " + member.String())
		}
	}
}

func updateClusterMarkIpL3(Ip string, Network string, Catid string) {
	for _, member := range detectMembers() {
		_, err := http.Post("http://"+member.String()+":22223/ipsetmarkiplayer3/"+Network+"/"+Catid+"/"+Ip+"/1", "application/json", body)
		if err != nil {
			fmt.Println("Not able to contact " + member.String())
		}
	}
}
func updateClusterMarkIpL2(Ip string, Network string, Catid string) {
	for _, member := range detectMembers() {
		_, err := http.Post("http://"+member.String()+":22223/ipsetmarkiplayer2/"+Network+"/"+Catid+"/"+Ip+"/1", "application/json", body)
		if err != nil {
			fmt.Println("Not able to contact " + member.String())
		}
	}
}
func mac2ip(Mac string) []string {
	var all []ipset.IPSet
	all, _ = ipset.ListAll()

	var Ips []string
	for _, v := range all {
		for _, u := range v.Members {
			r := "((?:[0-9]{1,3}.){3}(?:[0-9]{1,3}))," + Mac
			rgx, _ := regexp.Compile(r)
			if rgx.Match([]byte(u.Elem)) {
				result := rgx.FindStringSubmatch(u.Elem)
				fmt.Println(result[1])
				Ips = append(Ips, result[1])
			}
		}
	}
	return Ips
}
