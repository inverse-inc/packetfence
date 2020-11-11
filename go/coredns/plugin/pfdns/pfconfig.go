package pfdns

import (
	"context"
	"errors"
	"net"
	"regexp"

	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/inverse-inc/packetfence/go/timedlock"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// GlobalTransactionLock global var
var GlobalTransactionLock *timedlock.RWLock

func (pf *pfdns) Refresh(ctx context.Context) {
	// If some of the passthroughs were changed, we should reload
	if !pfconfigdriver.IsValid(ctx, &pfconfigdriver.Config.Passthroughs.Registration) || !pfconfigdriver.IsValid(ctx, &pfconfigdriver.Config.Passthroughs.Isolation) {
		log.LoggerWContext(ctx).Info("Reloading passthroughs and flushing cache")
		pf.PassthroughsInit(ctx)
		pf.PassthroughsIsolationInit(ctx)

		pf.DNSFilter.Flush()
		pf.IpsetCache.Flush()
	}
	if !pfconfigdriver.IsValid(ctx, &pfconfigdriver.Config.Dns.Configuration) {
		pf.DNSRecord(ctx)
	}
}

func (pf *pfdns) PassthroughsInit(ctx context.Context) error {

	pfconfigdriver.FetchDecodeSocket(ctx, &pfconfigdriver.Config.Passthroughs.Registration)

	pf.FqdnPort = make(map[*regexp.Regexp][]string)

	for k, v := range pfconfigdriver.Config.Passthroughs.Registration.Wildcard {
		rgx, _ := regexp.Compile(".*" + k)
		pf.FqdnPort[rgx] = v
	}

	for k, v := range pfconfigdriver.Config.Passthroughs.Registration.Normal {
		rgx, _ := regexp.Compile("^" + k + ".$")
		pf.FqdnPort[rgx] = v
	}

	return nil
}

func (pf *pfdns) PassthroughsIsolationInit(ctx context.Context) error {

	pfconfigdriver.FetchDecodeSocket(ctx, &pfconfigdriver.Config.Passthroughs.Isolation)

	pf.FqdnIsolationPort = make(map[*regexp.Regexp][]string)

	for k, v := range pfconfigdriver.Config.Passthroughs.Isolation.Wildcard {
		rgx, _ := regexp.Compile(".*" + k)
		pf.FqdnIsolationPort[rgx] = v
	}

	for k, v := range pfconfigdriver.Config.Passthroughs.Isolation.Normal {
		rgx, _ := regexp.Compile("^" + k + ".$")
		pf.FqdnIsolationPort[rgx] = v
	}
	return nil
}

func (pf *pfdns) DNSRecord(ctx context.Context) error {

	pfconfigdriver.FetchDecodeSocket(ctx, &pfconfigdriver.Config.Dns.Configuration)
	if pfconfigdriver.Config.Dns.Configuration.RecordDNS == "enabled" {
		pf.recordDNS = true
	} else {
		pf.recordDNS = false
	}
	return nil
}

// DetectVIP
func (pf *pfdns) detectVIP(ctx context.Context) error {

	var NetIndex net.IPNet

	pfconfigdriver.FetchDecodeSocket(ctx, &pfconfigdriver.Config.Interfaces.ListenInts)
	pfconfigdriver.FetchDecodeSocket(ctx, &pfconfigdriver.Config.Interfaces.DNSInts)

	var keyConfNet pfconfigdriver.PfconfigKeys
	keyConfNet.PfconfigNS = "config::Network"
	keyConfNet.PfconfigHostnameOverlay = "yes"
	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfNet)

	var keyConfCluster pfconfigdriver.NetInterface
	keyConfCluster.PfconfigNS = "config::Pf(CLUSTER," + pfconfigdriver.FindClusterName(ctx) + ")"

	var intDNS []string

	for _, vi := range pfconfigdriver.Config.Interfaces.DNSInts.Element {
		for key, DNSint := range vi.(map[string]interface{}) {
			if key == "int" {
				intDNS = append(intDNS, DNSint.(string))
			}
		}
	}
	id, err := GlobalTransactionLock.Lock()
	if err != nil {
		return errors.New("Unable to create a RWLock")
	}
	defer GlobalTransactionLock.Unlock(id)
	for _, v := range sharedutils.RemoveDuplicates(append(pfconfigdriver.Config.Interfaces.ListenInts.Element, intDNS...)) {

		keyConfCluster.PfconfigHashNS = "interface " + v
		pfconfigdriver.FetchDecodeSocket(ctx, &keyConfCluster)
		// Nothing in keyConfCluster.Ip so we are not in cluster mode
		var VIP net.IP

		eth, err := net.InterfaceByName(v)
		if err != nil {
			err = errors.New("Unable to get network interface " + v + " by name")
			continue
		}
		adresses, err := eth.Addrs()
		if err != nil {
			errors.New("Unable to get the ip addresses of the interface " + v)
			continue
		}
		for _, adresse := range adresses {
			var NetIP *net.IPNet
			var IP net.IP
			IP, NetIP, _ = net.ParseCIDR(adresse.String())
			a, b := NetIP.Mask.Size()
			if a == b {
				continue
			}
			if keyConfCluster.Ip != "" {
				VIP = net.ParseIP(keyConfCluster.Ip)
			} else {
				VIP = IP
			}
			for _, key := range keyConfNet.Keys {
				var ConfNet pfconfigdriver.NetworkConf
				ConfNet.PfconfigHashNS = key
				pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)
				if (NetIP.Contains(net.ParseIP(ConfNet.DhcpStart)) && NetIP.Contains(net.ParseIP(ConfNet.DhcpEnd))) || NetIP.Contains(net.ParseIP(ConfNet.NextHop)) {
					NetIndex.Mask = net.IPMask(net.ParseIP(ConfNet.Netmask))
					NetIndex.IP = net.ParseIP(key)
					Index := NetIndex
					pf.Network[Index.String()] = VIP
				}
				if ConfNet.RegNetwork != "" {
					IP2, NetIP2, _ := net.ParseCIDR(ConfNet.RegNetwork)
					if NetIP.Contains(IP2) {
						pf.Network[NetIP2.String()] = VIP
					}
				}
			}
		}
	}
	return nil
}
