// Package pfdns implements a plugin that returns details about the resolving
// querying it.
package pfdns

import (
	"database/sql"
	"errors"
	"fmt"
	"net"
	"os"
	"regexp"
	"time"

	"github.com/inverse-inc/packetfence/go/coredns/plugin"
	"github.com/inverse-inc/packetfence/go/coredns/request"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/filter_client"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
	cache "github.com/patrickmn/go-cache"
	//Import mysql driver
	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/miekg/dns"
	"golang.org/x/net/context"
)

type pfdns struct {
	RedirectIP        net.IP
	Db                *sql.DB
	IP4log            *sql.Stmt // prepared statement for ip4log queries
	IP6log            *sql.Stmt // prepared statement for ip6log queries
	Nodedb            *sql.Stmt // prepared statement for node table queries
	Violation         *sql.Stmt // prepared statement for violation
	Bh                bool      //  whether blackholing is enabled or not
	BhIP              net.IP
	BhCname           string
	Next              plugin.Handler
	Webservices       pfconfigdriver.PfConfWebservices
	FqdnPort          map[*regexp.Regexp][]string
	FqdnIsolationPort map[*regexp.Regexp][]string
	FqdnDomainPort    map[*regexp.Regexp][]string
	Network           map[*net.IPNet]net.IP
	NetworkType       map[*net.IPNet]string
	DNSFilter         *cache.Cache
	IpsetCache        *cache.Cache
	apiClient         *unifiedapiclient.Client
	PortalFQDN        string
}

// Ports array
type Ports struct {
	Port map[int]string
}

type dbConf struct {
	DBHost     string `json:"host"`
	DBPort     string `json:"port"`
	DBUser     string `json:"user"`
	DBPassword string `json:"pass"`
	DB         string `json:"db"`
}

func (pf *pfdns) Ip2Mac(ctx context.Context, ip string, ipVersion int) (string, error) {
	var (
		mac string
		err error
	)
	if ipVersion == 4 {
		err = pf.IP4log.QueryRow(ip, 1).Scan(&mac)
	} else {
		err = pf.IP6log.QueryRow(ip, 1).Scan(&mac)
	}

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Ip2Mac (ipv%d) mac for %s not found %s\n", ipVersion, ip, err))
	}

	return mac, err
}

func (pf *pfdns) HasViolations(ctx context.Context, mac string) bool {
	violation := false
	var violationCount int
	err := pf.Violation.QueryRow(mac, 1).Scan(&violationCount)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("HasViolation %s %s\n", mac, err))
	} else if violationCount != 0 {
		violation = true
	}

	return violation
}

// ServeDNS implements the middleware.Handler interface.
func (pf *pfdns) ServeDNS(ctx context.Context, w dns.ResponseWriter, r *dns.Msg) (int, error) {
	state := request.Request{W: w, Req: r}
	a := new(dns.Msg)
	a.SetReply(r)
	a.Compress = true
	a.Authoritative = true
	var rr dns.RR

	pffilter := filter_client.NewClient()

	var ipVersion int
	srcIP := state.IP()
	bIP := net.ParseIP(srcIP)
	if bIP.To4() == nil {
		ipVersion = 6
	} else {
		ipVersion = 4
	}

	mac, err := pf.Ip2Mac(ctx, srcIP, ipVersion)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("ERROR cannot find mac for ip %s\n", srcIP))
	}

	// Domain bypass
	for k, v := range pf.FqdnDomainPort {
		if k.MatchString(state.QName()) {
			answer, err := pf.LocalResolver(state)
			if err != nil {
				log.LoggerWContext(ctx).Error("Local resolver error for fqdn" + state.QName() + " with the following error" + err.Error())
			} else {
				for _, ans := range append(answer.Answer, answer.Extra...) {
					switch ansb := ans.(type) {
					case *dns.A:
						for _, valeur := range v {
							if err := pf.SetPassthrough(ctx, "passthrough", ansb.A.String(), valeur, true); err != nil {
								log.LoggerWContext(ctx).Error(fmt.Sprintf("Not able to contact localhost for setPassthrough %s", err))
							}
						}
					}
				}
				log.LoggerWContext(ctx).Debug(srcIP + " : " + mac + " Domain bypass for fqdn " + state.QName())
				w.WriteMsg(answer)
			}
			return 0, nil
		}
	}

	violation := pf.HasViolations(ctx, mac)
	if violation {
		// Passthrough bypass
		for k, v := range pf.FqdnIsolationPort {
			if k.MatchString(state.QName()) {
				answer, err := pf.LocalResolver(state)
				if err != nil {
					log.LoggerWContext(ctx).Error("Local resolver error for fqdn" + state.QName() + " with the following error" + err.Error())
				} else {
					for _, ans := range append(answer.Answer, answer.Extra...) {
						switch ansb := ans.(type) {
						case *dns.A:
							for _, valeur := range v {
								if err := pf.SetPassthrough(ctx, "passthrough_isolation", ansb.A.String(), valeur, false); err != nil {
									log.LoggerWContext(ctx).Error(fmt.Sprintf("Not able to contact Unified API to adjust passthroughs: %s", err))
								}
							}
						}
					}
					log.LoggerWContext(ctx).Debug(srcIP + " : " + mac + " isolation passthrough  for fqdn " + state.QName())
					w.WriteMsg(answer)
				}
				return 0, nil
			}
		}
	}

	// Passthrough bypass
	for k, v := range pf.FqdnPort {
		if k.MatchString(state.QName()) {
			answer, err := pf.LocalResolver(state)
			if err != nil {
				log.LoggerWContext(ctx).Error("Local resolver error for fqdn" + state.QName() + " with the following error" + err.Error())
			} else {
				for _, ans := range append(answer.Answer, answer.Extra...) {
					switch ansb := ans.(type) {
					case *dns.A:
						for _, valeur := range v {
							if err := pf.SetPassthrough(ctx, "passthrough", ansb.A.String(), valeur, false); err != nil {
								log.LoggerWContext(ctx).Error(fmt.Sprintf("Not able to contact Unified API to adjust passthroughs %s", err))
							}
						}
					}

				}
				w.WriteMsg(answer)
				log.LoggerWContext(ctx).Debug(srcIP + " : " + mac + " passthrough for fqdn " + state.QName())
			}
			return 0, nil
		}
	}

	// DNS Filter code
	var Type string

	for k, v := range pf.NetworkType {
		switch v {
		case "inlinel2":
			Type = "inline"

		case "inlinel3":
			Type = "inline"

		case "vlan-isolation":
			Type = "isolation"

		case "vlan-registration":
			Type = "registration"
		case "dns-enforcement":
			Type = "dnsenforcement"
		}

		if k.Contains(bIP) {
			// Register and inline or dns enforcement then resolv
			switch Type {
			case "dnsenforcement", "inline":
				var status = "unreg"
				err = pf.Nodedb.QueryRow(mac, 1).Scan(&status)
				if err != nil {
					log.LoggerWContext(ctx).Error(fmt.Sprintf("error getting node status %s %s\n", mac, err))
				}
				// Defer to the proxy middleware if the device is registered
				if status == "reg" && !violation {
					log.LoggerWContext(ctx).Debug(srcIP + " : " + mac + " serve dns " + state.QName())
					return pf.Next.ServeDNS(ctx, w, r)
				}
			}
			answer, found := pf.DNSFilter.Get(state.QName())
			if found && answer != "null" {
				log.LoggerWContext(ctx).Debug("Get answer from the cache for " + state.QName())
				rr, _ = dns.NewRR(answer.(string))
			} else {
				info, err := pffilter.FilterDns(Type, map[string]interface{}{
					"qname":    state.QName(),
					"peerhost": state.RemoteAddr(),
					"qtype":    state.QType(),
					"mac":      mac,
				})
				if err != nil {
					pf.DNSFilter.Set(state.QName(), "null", cache.DefaultExpiration)
					break
				}
				var answer string
				for a, b := range info.(map[string]interface{}) {
					if a == "answer" {
						answer = b.(string)
						break
					}
				}
				log.LoggerWContext(ctx).Debug("Get answer from pffilter for " + state.QName())
				pf.DNSFilter.Set(state.QName(), answer, cache.DefaultExpiration)
				rr, _ = dns.NewRR(answer)
			}

			a.Answer = []dns.RR{rr}
			log.LoggerWContext(ctx).Debug("DNS Filter matched for MAC " + mac + " IP " + srcIP + " Query " + state.QName())
			state.SizeAndDo(a)
			w.WriteMsg(a)
			return 0, nil
		}
	}

	switch state.Family() {
	case 1:
		rr = new(dns.A)
		if state.QName() == pf.PortalFQDN {
			rr.(*dns.A).Hdr = dns.RR_Header{Name: state.QName(), Rrtype: dns.TypeA, Class: state.QClass(), Ttl: 60}
		} else {
			rr.(*dns.A).Hdr = dns.RR_Header{Name: state.QName(), Rrtype: dns.TypeA, Class: state.QClass(), Ttl: 15}
		}
		for k, v := range pf.Network {
			if k.Contains(bIP) {
				returnedIP := append([]byte(nil), v.To4()...)
				rr.(*dns.A).A = returnedIP
				break
			} else {
				rr.(*dns.A).A = pf.RedirectIP.To4()
			}
		}
	case 2:
		rr = new(dns.AAAA)
		if state.QName() == pf.PortalFQDN {
			rr.(*dns.AAAA).Hdr = dns.RR_Header{Name: state.QName(), Rrtype: dns.TypeAAAA, Class: state.QClass(), Ttl: 60}
		} else {
			rr.(*dns.AAAA).Hdr = dns.RR_Header{Name: state.QName(), Rrtype: dns.TypeAAAA, Class: state.QClass(), Ttl: 15}
		}
		for k, v := range pf.Network {
			if k.Contains(bIP) {
				returnedIP := append([]byte(nil), v.To16()...)
				rr.(*dns.AAAA).AAAA = returnedIP
				break
			} else {
				rr.(*dns.AAAA).AAAA = pf.RedirectIP.To16()
			}
		}
	}

	a.Answer = []dns.RR{rr}
	log.LoggerWContext(ctx).Debug("Returned portal for MAC " + mac + " with IP " + srcIP + "for fqdn " + state.QName())
	state.SizeAndDo(a)
	w.WriteMsg(a)

	return 0, nil
}

// Name implements the Handler interface.
func (pf *pfdns) Name() string { return "pfdns" }

func readConfig(ctx context.Context) pfconfigdriver.PfConfDatabase {
	var sections pfconfigdriver.PfConfDatabase

	pfconfigdriver.FetchDecodeSocket(ctx, &sections)
	return sections
}

// DetectVIP
func (pf *pfdns) detectVIP() error {
	var ctx = context.Background()
	var NetIndex net.IPNet
	pf.Network = make(map[*net.IPNet]net.IP)

	var interfaces pfconfigdriver.ListenInts
	pfconfigdriver.FetchDecodeSocket(ctx, &interfaces)

	var keyConfNet pfconfigdriver.PfconfigKeys
	keyConfNet.PfconfigNS = "config::Network"
	keyConfNet.PfconfigHostnameOverlay = "yes"
	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfNet)

	var keyConfCluster pfconfigdriver.NetInterface
	keyConfCluster.PfconfigNS = "config::Pf(CLUSTER," + pfconfigdriver.FindClusterName(ctx) + ")"

	for _, v := range interfaces.Element {

		keyConfCluster.PfconfigHashNS = "interface " + v
		pfconfigdriver.FetchDecodeSocket(ctx, &keyConfCluster)
		// Nothing in keyConfCluster.Ip so we are not in cluster mode
		var VIP net.IP

		eth, _ := net.InterfaceByName(v)
		adresses, _ := eth.Addrs()
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
					pf.Network[&Index] = VIP
				}
				if ConfNet.RegNetwork != "" {
					IP2, NetIP2, _ := net.ParseCIDR(ConfNet.RegNetwork)
					if NetIP.Contains(IP2) {
						pf.Network[NetIP2] = VIP
					}
				}
			}
		}
	}
	return nil
}

func (pf *pfdns) DomainPassthroughInit() error {
	var ctx = context.Background()
	var keyConfDNS pfconfigdriver.PfconfigKeys
	keyConfDNS.PfconfigNS = "resource::domain_dns_servers"

	pf.FqdnDomainPort = make(map[*regexp.Regexp][]string)
	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfDNS)

	for _, v := range keyConfDNS.Keys {
		rgx, _ := regexp.Compile(".*(_msdcs|_sites)." + v)
		pf.FqdnDomainPort[rgx] = []string{"udp:88", "udp:123", "udp:135", "tcp:135", "udp:137", "udp:138", "udp:139", "tcp:139", "udp:389", "udp:445", "tcp:445", "udp:464", "tcp:464", "tcp:1025", "udp:49155", "tcp:49155", "udp:49156", "tcp:49156", "udp:49172", "tcp:49172"}
	}

	return nil

}

// WebservicesInit read pfconfig webservices configuration
func (pf *pfdns) WebservicesInit() error {
	var ctx = context.Background()
	var webservices pfconfigdriver.PfConfWebservices
	webservices.PfconfigNS = "config::Pf"
	webservices.PfconfigMethod = "hash_element"
	webservices.PfconfigHashNS = "webservices"

	pfconfigdriver.FetchDecodeSocket(ctx, &webservices)
	pf.Webservices = webservices
	return nil

}

func (pf *pfdns) PassthrouthsInit() error {
	var ctx = context.Background()

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

func (pf *pfdns) PassthrouthsIsolationInit() error {
	var ctx = context.Background()

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

// detectType of each network
func (pf *pfdns) detectType() error {
	var ctx = context.Background()
	var NetIndex net.IPNet
	pf.NetworkType = make(map[*net.IPNet]string)

	var interfaces pfconfigdriver.ListenInts
	pfconfigdriver.FetchDecodeSocket(ctx, &interfaces)

	var keyConfNet pfconfigdriver.PfconfigKeys
	keyConfNet.PfconfigNS = "config::Network"
	keyConfNet.PfconfigHostnameOverlay = "yes"
	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfNet)

	var keyConfCluster pfconfigdriver.NetInterface
	keyConfCluster.PfconfigNS = "config::Pf(CLUSTER," + pfconfigdriver.FindClusterName(ctx) + ")"

	for _, v := range interfaces.Element {

		keyConfCluster.PfconfigHashNS = "interface " + v
		pfconfigdriver.FetchDecodeSocket(ctx, &keyConfCluster)
		// Nothing in keyConfCluster.Ip so we are not in cluster mode

		eth, _ := net.InterfaceByName(v)
		adresses, _ := eth.Addrs()
		for _, adresse := range adresses {
			var NetIP *net.IPNet
			_, NetIP, _ = net.ParseCIDR(adresse.String())
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
					pf.NetworkType[&Index] = ConfNet.Type
				}
				if ConfNet.RegNetwork != "" {
					IP2, NetIP2, _ := net.ParseCIDR(ConfNet.RegNetwork)
					if NetIP.Contains(IP2) {
						pf.NetworkType[NetIP2] = ConfNet.Type
					}
				}
			}
		}
	}
	return nil
}

func (pf *pfdns) DbInit() error {
	var ctx = context.Background()

	var err error

	db, err := db.DbFromConfig(ctx)
	sharedutils.CheckError(err)
	pf.Db = db

	pf.IP4log, err = pf.Db.Prepare("select mac from ip4log where ip = ? AND tenant_id = ?")
	if err != nil {
		fmt.Fprintf(os.Stderr, "pfdns: database ip4log prepared statement error: %s", err)
		return err
	}

	pf.IP6log, err = pf.Db.Prepare("select mac from ip6log where ip = ? AND tenant_id = ?")
	if err != nil {
		fmt.Fprintf(os.Stderr, "pfdns: database ip6log prepared statement error: %s", err)
		return err
	}

	pf.Nodedb, err = pf.Db.Prepare("select status from node where mac = ? AND tenant_id = ?")
	if err != nil {
		fmt.Fprintf(os.Stderr, "pfdns: database nodedb prepared statement error: %s", err)
		return err
	}

	pf.Violation, err = pf.Db.Prepare("Select count(*) from violation, action where violation.vid=action.vid and action.action='reevaluate_access' and mac=? and status='open' AND tenant_id = ?")
	if err != nil {
		fmt.Fprintf(os.Stderr, "pfdns: database violation prepared statement error: %s", err)
		return err
	}

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error while connecting to database: %s", err))
		return err
	}

	return nil
}

func (pf *pfdns) LocalResolver(request request.Request) (*dns.Msg, error) {
	const (
		// DefaultTimeout is default timeout many operation in this program will
		// use.
		DefaultTimeout time.Duration = 5 * time.Second
	)
	localc := dns.Client{
		ReadTimeout: DefaultTimeout,
	}
	request.Req.RecursionDesired = true
	r, _, err := localc.Exchange(request.Req, "127.0.0.1:54")
	if err != nil {
		localc.Net = "tcp"
		r, _, err = localc.Exchange(request.Req, "127.0.0.1:54")
		if err != nil {
			return nil, err
		}
	}

	if r == nil || r.Rcode == dns.RcodeNameError || r.Rcode == dns.RcodeSuccess {
		return r, err
	}

	return nil, errors.New("No name server to answer the question")
}

func (pf *pfdns) SetPassthrough(ctx context.Context, passthrough, ip, port string, local bool) error {
	query_local := "0"
	if local {
		query_local = "1"
	}

	cache_key := passthrough + ":" + ip + ":" + port + ":" + query_local
	_, found := pf.IpsetCache.Get(cache_key)
	if found {
		return nil
	}

	err := pf.apiClient.CallWithBody(ctx, "POST", "/api/v1/ipset/"+passthrough+"?local="+query_local, map[string]interface{}{
		"ip":   ip,
		"port": port,
	}, &unifiedapiclient.DummyReply{})

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Not able to contact Unified API to adjust passthroughs %s", err))
	} else {
		pf.IpsetCache.Set(cache_key, 1, cache.DefaultExpiration)
	}

	return err
}

func (pf *pfdns) PortalFQDNInit() error {
	general := pfconfigdriver.Config.PfConf.General
	pf.PortalFQDN = general.Hostname + "." + general.Domain + "."
	return nil
}
