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
	p := &pfdnsRefreshableConfig{
		DNSFilter:  cache.New(300*time.Second, 10*time.Second),
		IpsetCache: cache.New(1*time.Hour, 10*time.Second),
	}
	pfconfigdriver.FetchDecodeSocket(ctx, &p.registration)
	pfconfigdriver.FetchDecodeSocket(ctx, &p.isolation)
	pfconfigdriver.FetchDecodeSocket(ctx, &p.PfConfDns)
	p.PassthroughsInit(ctx)
	p.PassthroughsIsolationInit(ctx)
	p.recordDNS = p.PfConfDns.RecordDNS == "enabled"
	return p
}

func (pf *pfdnsRefreshableConfig) PassthroughsInit(ctx context.Context) error {
	pfconfigdriver.FetchDecodeSocket(ctx, &pf.registration)

	pf.FqdnPort = make(map[*regexp.Regexp][]string)

	for k, v := range pf.registration.Wildcard {
		rgx, _ := regexp.Compile(".*" + k)
		pf.FqdnPort[rgx] = v
	}

	for k, v := range pf.registration.Normal {
		rgx, _ := regexp.Compile("^" + k + ".$")
		pf.FqdnPort[rgx] = v
	}

	return nil
}

func (pf *pfdnsRefreshableConfig) PassthroughsIsolationInit(ctx context.Context) error {
	pfconfigdriver.FetchDecodeSocket(ctx, &pf.isolation)

	pf.FqdnIsolationPort = make(map[*regexp.Regexp][]string)

	for k, v := range pf.isolation.Wildcard {
		rgx, _ := regexp.Compile(".*" + k)
		pf.FqdnIsolationPort[rgx] = v
	}

	for k, v := range pf.isolation.Normal {
		rgx, _ := regexp.Compile("^" + k + ".$")
		pf.FqdnIsolationPort[rgx] = v
	}

	return nil
}

func (p *pfdnsRefreshableConfig) IsValid(ctx context.Context) bool {
	return pfconfigdriver.IsValid(ctx, &p.registration) && pfconfigdriver.IsValid(ctx, &p.isolation) && pfconfigdriver.IsValid(ctx, &p.PfConfDns)
}

func (p *pfdnsRefreshableConfig) Refresh(ctx context.Context) {
	if !pfconfigdriver.IsValid(ctx, &p.registration) || !pfconfigdriver.IsValid(ctx, &p.isolation) {
		p.PassthroughsInit(ctx)
		p.PassthroughsIsolationInit(ctx)
		p.DNSFilter = cache.New(300*time.Second, 10*time.Second)
		p.IpsetCache = cache.New(1*time.Hour, 10*time.Second)
	}

	pfconfigdriver.FetchDecodeSocket(ctx, &p.PfConfDns)
	p.recordDNS = p.PfConfDns.RecordDNS == "enabled"
}

func (p *pfdnsRefreshableConfig) Clone() pfconfigdriver.Refresh {
	return &pfdnsRefreshableConfig{
		registration: p.registration,
		isolation:    p.isolation,
		PfConfDns:    p.PfConfDns,
		DNSFilter:    p.DNSFilter,
		IpsetCache:   p.IpsetCache,
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
