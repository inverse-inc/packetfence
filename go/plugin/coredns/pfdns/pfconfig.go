package pfdns

import (
	"context"
	"errors"
	"net"
	"regexp"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/timedlock"
	cache "github.com/patrickmn/go-cache"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// GlobalTransactionLock global var
var GlobalTransactionLock *timedlock.RWLock

type pfdnsRefreshableConfig struct {
	registration      pfconfigdriver.PassthroughsConf
	isolation         pfconfigdriver.PassthroughsIsolationConf
	PfConfDns         pfconfigdriver.PfConfDns
	DNSFilter         *cache.Cache
	IpsetCache        *cache.Cache
	FqdnPort          map[*regexp.Regexp][]string
	FqdnIsolationPort map[*regexp.Regexp][]string
	recordDNS         bool
}

func newPfconfigRefreshableConfig(ctx context.Context) *pfdnsRefreshableConfig {
	rc := &pfdnsRefreshableConfig{
		DNSFilter:  cache.New(300*time.Second, 10*time.Second),
		IpsetCache: cache.New(1*time.Hour, 10*time.Second),
	}
	pfconfigdriver.FetchDecodeSocket(ctx, &rc.registration)
	pfconfigdriver.FetchDecodeSocket(ctx, &rc.isolation)
	pfconfigdriver.FetchDecodeSocket(ctx, &rc.PfConfDns)
	rc.PassthroughsInit(ctx)
	rc.PassthroughsIsolationInit(ctx)
	rc.recordDNS = sharedutils.IsEnabled(rc.PfConfDns.RecordDNS)
	return rc
}

func (rc *pfdnsRefreshableConfig) PassthroughsInit(ctx context.Context) error {
	rc.FqdnPort = make(map[*regexp.Regexp][]string)

	for k, v := range rc.registration.Wildcard {
		rgx, _ := regexp.Compile(".*" + k)
		rc.FqdnPort[rgx] = v
	}

	for k, v := range rc.registration.Normal {
		rgx, _ := regexp.Compile("^" + k + ".$")
		rc.FqdnPort[rgx] = v
	}

	return nil
}

func (rc *pfdnsRefreshableConfig) PassthroughsIsolationInit(ctx context.Context) error {
	rc.FqdnIsolationPort = make(map[*regexp.Regexp][]string)

	for k, v := range rc.isolation.Wildcard {
		rgx, _ := regexp.Compile(".*" + k)
		rc.FqdnIsolationPort[rgx] = v
	}

	for k, v := range rc.isolation.Normal {
		rgx, _ := regexp.Compile("^" + k + ".$")
		rc.FqdnIsolationPort[rgx] = v
	}

	return nil
}

func (rc *pfdnsRefreshableConfig) IsValid(ctx context.Context) bool {
	return pfconfigdriver.IsValid(ctx, &rc.registration) && pfconfigdriver.IsValid(ctx, &rc.isolation) && pfconfigdriver.IsValid(ctx, &rc.PfConfDns)
}

func (rc *pfdnsRefreshableConfig) Refresh(ctx context.Context) {
	pfconfigdriver.FetchDecodeSocket(ctx, &rc.registration)
	pfconfigdriver.FetchDecodeSocket(ctx, &rc.isolation)
	pfconfigdriver.FetchDecodeSocket(ctx, &rc.PfConfDns)
	rc.PassthroughsInit(ctx)
	rc.PassthroughsIsolationInit(ctx)

	rc.recordDNS = sharedutils.IsEnabled(rc.PfConfDns.RecordDNS)
}

func (rc *pfdnsRefreshableConfig) Clone() pfconfigdriver.Refresh {
	return &pfdnsRefreshableConfig{
		registration: rc.registration,
		isolation:    rc.isolation,
		PfConfDns:    rc.PfConfDns,
		DNSFilter:    rc.DNSFilter,
		IpsetCache:   rc.IpsetCache,
	}
}

// DetectVIP
func (pf *pfdns) detectVIP(ctx context.Context) error {

	var NetIndex net.IPNet
	listenInts := pfconfigdriver.GetType[pfconfigdriver.ListenInts](ctx)
	dnsInts := pfconfigdriver.GetType[pfconfigdriver.DNSInts](ctx)

	var keyConfNet pfconfigdriver.PfconfigKeys
	keyConfNet.PfconfigNS = "config::Network"
	keyConfNet.PfconfigHostnameOverlay = "yes"
	err := pfconfigdriver.FetchDecodeSocket(ctx, &keyConfNet)
	if err != nil {
		log.LoggerWContext(ctx).Error(err.Error())
		return errors.New("Unable to fetch config::Network from pfconfig")
	}
	var keyConfCluster pfconfigdriver.NetInterface
	keyConfCluster.PfconfigNS = "config::Pf(CLUSTER," + pfconfigdriver.FindClusterName(ctx) + ")"

	var intDNS []string

	for _, vi := range dnsInts.Element {
		for key, DNSint := range vi.(map[string]interface{}) {
			if key == "int" {
				intDNS = append(intDNS, DNSint.(string))
			}
		}
	}
	for _, v := range sharedutils.RemoveDuplicates(append(listenInts.Element, intDNS...)) {

		keyConfCluster.PfconfigHashNS = "interface " + v
		err = pfconfigdriver.FetchDecodeSocket(ctx, &keyConfCluster)
		if err != nil {
			log.LoggerWContext(ctx).Error(err.Error())
			continue
		}

		// Nothing in keyConfCluster.Ip so we are not in cluster mode
		var VIP net.IP

		eth, err := net.InterfaceByName(v)
		if err != nil {
			err = errors.New("Unable to get network interface " + v + " by name")
			continue
		}
		adresses, err := eth.Addrs()
		if err != nil {
			err = errors.New("Unable to get the ip addresses of the interface " + v)
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
				err = pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)
				if err != nil {
					log.LoggerWContext(ctx).Error(err.Error())
					continue
				}

				id, err := GlobalTransactionLock.Lock()
				if err != nil {
					return errors.New("Unable to create a RWLock")
				}

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
				GlobalTransactionLock.Unlock(id)
			}
		}
	}
	return nil
}
