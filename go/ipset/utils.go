package main

import (
	"net"
	"net/http"

	"github.com/davecgh/go-spew/spew"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

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
				// spew.Dump(net.ParseCIDR(UnicastAddr.String()))
				// spew.Dump(IP)
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
		_, err := http.Get("http://" + member.String() + ":22223/ipsetlayer2/" + Type + "/" + Catid + "/" + Ip + "/" + Mac + "/1")
		if err == nil {

		}
		spew.Dump(member)
	}
}

func updateClusterL3(Ip string, Network string, Type string, Catid string) {
	for _, member := range detectMembers() {
		_, err := http.Get("http://" + member.String() + ":22223/ipsetlayer3/" + Type + "/" + Catid + "/" + Ip + "/1")
		if err == nil {

		}
		spew.Dump(member)
	}
}
