// Package pfdns implements a plugin that returns details about the resolving
// querying it.
package pfdns

import (
	"bytes"
	"database/sql"
	"errors"
	"fmt"

	"net"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"sync"
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
	RedirectIP          net.IP
	Db                  *sql.DB
	IP4log              *sql.Stmt // prepared statement for ip4log queries
	IP6log              *sql.Stmt // prepared statement for ip6log queries
	Nodedb              *sql.Stmt // prepared statement for node table queries
	SecurityEvent       *sql.Stmt // prepared statement for security_event
	DNSAudit            *sql.Stmt // prepared statement for dns_audit_log
	Bh                  bool      //  whether blackholing is enabled or not
	BhIP                net.IP
	BhCname             string
	Next                plugin.Handler
	Webservices         pfconfigdriver.PfConfWebservices
	FqdnPort            map[*regexp.Regexp][]string
	FqdnIsolationPort   map[*regexp.Regexp][]string
	FqdnDomainPort      map[*regexp.Regexp][]string
	Network             map[*net.IPNet]net.IP
	NetworkType         map[*net.IPNet]string
	DNSFilter           *cache.Cache
	IpsetCache          *cache.Cache
	apiClient           *unifiedapiclient.Client
	refreshLauncher     *sync.Once
	PortalFQDN          map[int]map[*net.IPNet]*regexp.Regexp
	mutex               sync.Mutex
	detectionMechanisms []*regexp.Regexp
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

func (pf *pfdns) HasSecurityEvents(ctx context.Context, mac string) bool {
	security_event := false
	var securityEventCount int
	err := pf.SecurityEvent.QueryRow(mac, 1).Scan(&securityEventCount)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("HasSecurityEvent %s %s\n", mac, err))
	} else if securityEventCount != 0 {
		security_event = true
	}

	return security_event
}

func (pf *pfdns) RefreshPfconfig(ctx context.Context) {
	id, err := pfconfigdriver.PfconfigPool.ReadLock(ctx)
	if err == nil {
		defer pfconfigdriver.PfconfigPool.ReadUnlock(ctx, id)

		// We launch the refresh job once, the first time a request comes in
		// This ensures that the pool will run with a context that represents a request (log level for instance)
		pf.refreshLauncher.Do(func() {
			ctx := ctx
			go func(ctx context.Context) {
				for {
					pfconfigdriver.PfconfigPool.Refresh(ctx)
					time.Sleep(1 * time.Second)
				}
			}(ctx)
		})
	} else {
		panic("Unable to obtain pfconfigpool lock in pfdns middleware")
	}
}

// ServeDNS implements the middleware.Handler interface.
func (pf *pfdns) ServeDNS(ctx context.Context, w dns.ResponseWriter, r *dns.Msg) (int, error) {

	pf.RefreshPfconfig(ctx)

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
		mac = "00:00:00:00:00:00"
	}

	var answer *dns.Msg

	// defer pf.logreply(ctx, mac, state.QName(), state.Type(), a, answer)

	var status = "unreg"
	var category string
	err = pf.Nodedb.QueryRow(mac, 1).Scan(&status, &category)
	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("error getting node status %s %s\n", mac, err))
	}

	var PortalDetection bool
	PortalDetection = false
	if pf.checkDetectionMechanisms(ctx, state.QName()) {
		PortalDetection = true
		log.LoggerWContext(ctx).Debug("Portal Detection Mechanisms detected " + state.QName())
	}

	// Domain bypass
	for k, v := range pf.FqdnDomainPort {
		if k.MatchString(state.QName()) {
			answer, err = pf.LocalResolver(state)
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
				state.SizeAndDo(answer)
				pf.logreply(ctx, mac, state.QName(), state.Type(), answer)
				w.WriteMsg(answer)

			}
			return 0, nil
		}
	}

	security_event := pf.HasSecurityEvents(ctx, mac)
	if security_event {
		// Passthrough bypass
		if !(PortalDetection) {

			for k, v := range pf.FqdnIsolationPort {
				if k.MatchString(state.QName()) {
					answer, err = pf.LocalResolver(state)
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
						state.SizeAndDo(answer)
						pf.logreply(ctx, mac, state.QName(), state.Type(), answer)
						w.WriteMsg(answer)
					}
					return 0, nil
				}
			}
		}
	}
	// Passthrough bypass
	if !(PortalDetection) {
		for k, v := range pf.FqdnPort {
			if k.MatchString(state.QName()) {
				answer, err = pf.LocalResolver(state)
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
					state.SizeAndDo(answer)
					pf.logreply(ctx, mac, state.QName(), state.Type(), answer)
					w.WriteMsg(answer)
					log.LoggerWContext(ctx).Debug(srcIP + " : " + mac + " passthrough for fqdn " + state.QName())
				}
				return 0, nil
			}
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

				err = pf.Nodedb.QueryRow(mac, 1).Scan(&status, &category)
				if err != nil {
					log.LoggerWContext(ctx).Error(fmt.Sprintf("error getting node status %s %s\n", mac, err))
				}
				// Defer to the proxy middleware if the device is registered
				if status == "reg" && !security_event && category != "REJECT" {
					log.LoggerWContext(ctx).Debug(srcIP + " : " + mac + " serve dns " + state.QName())
					return pf.Next.ServeDNS(ctx, w, r)
				} else if status == "reg" && category == "REJECT" {
					rr, _ = dns.NewRR("30 IN A 127.0.0.1")
					a.Answer = []dns.RR{rr}
					log.LoggerWContext(ctx).Debug("REJECT " + mac + " IP " + srcIP + " Query " + state.QName())
					state.SizeAndDo(a)
					pf.logreply(ctx, mac, state.QName(), state.Type(), a)
					w.WriteMsg(a)
					return 0, nil
				}
			}

			cacheKey := pf.MakeKeyCache(mac, category, security_event, state.QName())
			reply, found := pf.DNSFilter.Get(cacheKey)
			if found && reply != "null" {
				log.LoggerWContext(ctx).Debug("Get answer from the cache for " + state.QName())
				rr, _ = dns.NewRR(reply.(string))
			} else {
				info, err := pffilter.FilterDns(Type, map[string]interface{}{
					"qname":    state.QName(),
					"peerhost": state.RemoteAddr(),
					"qtype":    state.QType(),
					"mac":      mac,
				})
				if err != nil {
					pf.DNSFilter.Set(cacheKey, "null", cache.DefaultExpiration)
					break
				}
				var response string
				for a, b := range info.(map[string]interface{}) {
					if a == "answer" {
						response = b.(string)
						break
					}
				}
				log.LoggerWContext(ctx).Debug("Get answer from pffilter for " + state.QName())
				pf.DNSFilter.Set(cacheKey, response, cache.DefaultExpiration)
				rr, _ = dns.NewRR(response)
			}

			a.Answer = []dns.RR{rr}
			log.LoggerWContext(ctx).Debug("DNS Filter matched for MAC " + mac + " IP " + srcIP + " Query " + state.QName())
			state.SizeAndDo(a)
			pf.logreply(ctx, mac, state.QName(), state.Type(), a)
			w.WriteMsg(a)
			return 0, nil
		}
	}

	switch state.Family() {
	case 1:
		rr = new(dns.A)
		var found bool
		found = false
		for i := 0; i <= len(pf.PortalFQDN); i++ {
			if found {
				break
			}
			for c, d := range pf.PortalFQDN[i] {
				if c.Contains(bIP) {
					if d.MatchString(state.QName()) {
						rr.(*dns.A).Hdr = dns.RR_Header{Name: state.QName(), Rrtype: dns.TypeA, Class: state.QClass(), Ttl: 60}
					} else {
						rr.(*dns.A).Hdr = dns.RR_Header{Name: state.QName(), Rrtype: dns.TypeA, Class: state.QClass(), Ttl: 15}
					}
					found = true
					break
				}
			}
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
		var found bool
		found = false
		for i := 0; i <= len(pf.PortalFQDN); i++ {
			if found {
				break
			}
			for c, d := range pf.PortalFQDN[i] {
				if c.Contains(bIP) {
					if d.MatchString(state.QName()) {
						rr.(*dns.AAAA).Hdr = dns.RR_Header{Name: state.QName(), Rrtype: dns.TypeAAAA, Class: state.QClass(), Ttl: 60}
					} else {
						rr.(*dns.AAAA).Hdr = dns.RR_Header{Name: state.QName(), Rrtype: dns.TypeAAAA, Class: state.QClass(), Ttl: 15}
					}
					found = true
					break
				}
			}
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
	pf.logreply(ctx, mac, state.QName(), state.Type(), a)
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

	var DNSinterfaces pfconfigdriver.DNSInts
	pfconfigdriver.FetchDecodeSocket(ctx, &DNSinterfaces)

	var keyConfNet pfconfigdriver.PfconfigKeys
	keyConfNet.PfconfigNS = "config::Network"
	keyConfNet.PfconfigHostnameOverlay = "yes"
	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfNet)

	var keyConfCluster pfconfigdriver.NetInterface
	keyConfCluster.PfconfigNS = "config::Pf(CLUSTER," + pfconfigdriver.FindClusterName(ctx) + ")"

	var int_dns []string

	for _, vi := range DNSinterfaces.Element {
		for key, dns_int := range vi.(map[string]interface{}) {
			if key == "int" {
				int_dns = append(int_dns, dns_int.(string))
			}
		}
	}

	for _, v := range sharedutils.RemoveDuplicates(append(interfaces.Element, int_dns...)) {

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
		pf.FqdnDomainPort[rgx] = []string{
			"tcp:88",
			"udp:88",
			"udp:123",
			"udp:135",
			"tcp:135",
			"udp:137",
			"udp:138",
			"udp:139",
			"tcp:139",
			"tcp:389",
			"udp:389",
			"udp:445",
			"tcp:445",
			"udp:464",
			"tcp:464",
			"tcp:1025",
			"udp:49155",
			"tcp:49155",
			"udp:49156",
			"tcp:49156",
			"udp:49172",
			"tcp:49172",
		}
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

	pf.Nodedb, err = pf.Db.Prepare("select node.status, IF(ISNULL(nc.name), '', nc.name) as category from node LEFT JOIN node_category as nc on node.category_id = nc.category_id where mac = ? AND tenant_id = ?")
	if err != nil {
		fmt.Fprintf(os.Stderr, "pfdns: database nodedb prepared statement error: %s", err)
		return err
	}

	pf.SecurityEvent, err = pf.Db.Prepare("Select count(*) from security_event, action where security_event.security_event_id=action.security_event_id and action.action='reevaluate_access' and mac=? and status='open' AND tenant_id = ?")
	if err != nil {
		fmt.Fprintf(os.Stderr, "pfdns: database security_event prepared statement error: %s", err)
		return err
	}

	pf.DNSAudit, err = pf.Db.Prepare("insert into dns_audit_log (mac, qname, qtype, answer) VALUES (?, ?, ?, ?)")
	if err != nil {
		fmt.Fprintf(os.Stderr, "pfdns: database security_event prepared statement error: %s", err)
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

func (pf *pfdns) PortalFQDNInit(ctx context.Context) error {
	general := pfconfigdriver.Config.PfConf.General

	index := 0

	pf.PortalFQDN = make(map[int]map[*net.IPNet]*regexp.Regexp)

	var interfaces pfconfigdriver.ListenInts
	pfconfigdriver.FetchDecodeSocket(ctx, &interfaces)

	var keyConfNet pfconfigdriver.PfconfigKeys
	keyConfNet.PfconfigNS = "config::Network"
	keyConfNet.PfconfigHostnameOverlay = "yes"
	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfNet)

	for _, key := range keyConfNet.Keys {
		var ConfNet pfconfigdriver.NetworkConf
		ConfNet.PfconfigHashNS = key
		pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)

		var fqdn string
		if ConfNet.PortalFQDN != "" {
			fqdn = ConfNet.PortalFQDN
		} else {
			fqdn = general.Hostname + "." + general.Domain
		}
		NetIndex := &net.IPNet{}
		NetIndex.Mask = net.IPMask(net.ParseIP(ConfNet.Netmask))
		NetIndex.IP = net.ParseIP(key)

		rgx, _ := regexp.Compile(".*" + fqdn)

		pf.PortalFQDN[index] = make(map[*net.IPNet]*regexp.Regexp)
		pf.PortalFQDN[index][NetIndex] = rgx
		index++
	}
	NetIndex := &net.IPNet{}
	NetIndex.Mask = net.IPMask(net.IPv4zero)
	NetIndex.IP = net.IPv4zero
	pf.PortalFQDN[index] = make(map[*net.IPNet]*regexp.Regexp)
	rgx, _ := regexp.Compile(".*" + general.Hostname + "." + general.Domain)
	pf.PortalFQDN[index][NetIndex] = rgx

	return nil
}

func (pf *pfdns) MakeKeyCache(mac string, category string, security_event bool, qname string) string {
	return mac + category + strconv.FormatBool(security_event) + qname
}

func (pf *pfdns) MakeDetectionMecanism(ctx context.Context) error {
	portal := pfconfigdriver.Config.PfConf.CaptivePortal
	pf.detectionMechanisms = make([]*regexp.Regexp, 0)
	var err error
	for _, v := range portal.DetectionMecanismUrls {
		fqdn, err := url.Parse(v)
		if err != nil {
			log.LoggerWContext(ctx).Error(fmt.Sprintf("Not able to parse the url %s", err))
			continue
		}
		err = pf.addDetectionMechanismsToList(ctx, fqdn.Host)
	}
	return err
}

// addDetectionMechanismsToList add all detection mechanisms in a list
func (pf *pfdns) addDetectionMechanismsToList(ctx context.Context, r string) error {
	rgx, err := regexp.Compile(r)
	if err == nil {
		pf.mutex.Lock()
		pf.detectionMechanisms = append(pf.detectionMechanisms, rgx)
		pf.mutex.Unlock()
	} else {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Not able to compile the regexp %s", err))
	}
	return err
}

// checkDetectionMechanisms compare the url to the detection mechanisms regex
func (pf *pfdns) checkDetectionMechanisms(ctx context.Context, e string) bool {
	if pf.detectionMechanisms == nil {
		return false
	}

	for _, rgx := range pf.detectionMechanisms {
		if rgx.MatchString(e) {
			return true
		}
	}
	return false
}

// Track timing for each function
func (pf *pfdns) logreply(ctx context.Context, mac string, qname string, qtype string, reply *dns.Msg) {
	var b bytes.Buffer
	var re = regexp.MustCompile(`\s+`)

	for _, rr := range reply.Answer {
		text := re.ReplaceAllString(rr.String(), " ")
		b.WriteString(text)
	}
	pf.DNSAudit.ExecContext(ctx, mac, qname, qtype, b.String())
}
