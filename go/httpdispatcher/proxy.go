package httpdispatcher

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"regexp"
	"strings"
	"sync"
	"text/template"
	"time"

	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

// Proxy structure
type Proxy struct {
	endpointWhiteList    []*regexp.Regexp
	endpointBlackList    []*regexp.Regexp
	mutex                sync.Mutex
	ParkingSecurityEvent *sql.Stmt // prepared statement for security_event
	IP4log               *sql.Stmt // prepared statement for ip4log queries
	IP6log               *sql.Stmt // prepared statement for ip6log queries
	Db                   *sql.DB
	apiClient            *unifiedapiclient.Client
}

type passthrough struct {
	proxypassthrough        []*regexp.Regexp
	detectionmechanisms     []*regexp.Regexp
	DetectionMecanismBypass bool
	mutex                   sync.Mutex
	PortalURL               map[int]map[*net.IPNet]*url.URL
	URIException            *regexp.Regexp
	SecureRedirect          bool
}

type fqdn struct {
	FQDN map[*net.IPNet]*url.URL
}

var passThrough *passthrough

// TenantID constant
const TenantID = 1

// NewProxy creates a new instance of proxy.
// It sets request logger using rLogPath as output file or os.Stdout by default.
// If whitePath of blackPath is not empty they are parsed to set endpoint lists.
func NewProxy(ctx context.Context) *Proxy {
	var p Proxy

	passThrough = newProxyPassthrough(ctx)
	passThrough.readConfig(ctx)
	p.Configure(ctx)
	return &p
}

// Refresh the configuration
func (p *Proxy) Refresh(ctx context.Context) {
	passThrough.readConfig(ctx)
}

// addToEndpointList compiles regex and adds it to an endpointList
// if regex is valid
// use t to choose list type: true for whitelist false for blacklist
func (p *Proxy) addToEndpointList(ctx context.Context, r string) error {
	rgx, err := regexp.Compile(r)
	if err == nil {
		p.mutex.Lock()
		p.endpointBlackList = append(p.endpointBlackList, rgx)
		p.mutex.Unlock()
	}
	return err
}

// checkEndpointList looks if r is in whitelist or blackllist
// returns true if endpoint is allowed
func (p *Proxy) checkEndpointList(ctx context.Context, e string) bool {
	if p.endpointBlackList == nil && p.endpointWhiteList == nil {
		return true
	}

	for _, rgx := range p.endpointBlackList {
		if rgx.MatchString(e) {
			return false
		}
	}

	return true
}

// ServeHTTP satisfy HandlerFunc interface and
// log, authorize and forward requests
func (p *Proxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	host := r.Host
	var fqdn url.URL
	fqdn.Scheme = r.Header.Get("X-Forwarded-Proto")
	fqdn.Host = r.Host
	fqdn.Path = r.RequestURI
	fqdn.ForceQuery = false
	fqdn.RawQuery = ""

	if host == "" {
		w.WriteHeader(http.StatusBadGateway)
		return
	}

	p.handleParking(ctx, w, r)

	if r.URL.Path == "/kindle-wifi/wifistub.html" {
		log.LoggerWContext(ctx).Debug(fmt.Sprintln(host, "KINDLE WIFI PROBE HANDLING"))
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>Kindle Reachability Probe Page</title>
<META http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<!--81ce4465-7167-4dcb-835b-dcc9e44c112a created with python 2.5 uuid.uuid4()-->
</head>
<body bgcolor="#ffffff" text="#000000">
81ce4465-7167-4dcb-835b-dcc9e44c112a
</body>
</html>

`))
		return
	}

	if !(passThrough.checkProxyPassthrough(ctx, host) || ((passThrough.checkDetectionMechanisms(ctx, fqdn.String()) || passThrough.URIException.MatchString(r.RequestURI)) && passThrough.DetectionMecanismBypass)) {
		if r.Method != "GET" && r.Method != "HEAD" {
			log.LoggerWContext(ctx).Debug(fmt.Sprintln(host, "FORBIDDEN"))
			w.WriteHeader(http.StatusNotImplemented)
			return
		}

		var PortalURL url.URL
		var found bool
		found = false
		srcIP := net.ParseIP(r.Header.Get("X-Forwarded-For"))
		for i := 0; i <= len(passThrough.PortalURL); i++ {
			if found {
				break
			}
			for c, d := range passThrough.PortalURL[i] {
				if c.Contains(srcIP) {
					PortalURL = *d
					found = true
					break
				}
			}
		}

		if (passThrough.checkDetectionMechanisms(ctx, fqdn.String()) || passThrough.URIException.MatchString(r.RequestURI)) && passThrough.SecureRedirect {
			PortalURL.Scheme = "http"
		}
		log.LoggerWContext(ctx).Debug(fmt.Sprintln(host, "Redirect to the portal"))
		PortalURL.RawQuery = "destination_url=" + r.Header.Get("X-Forwarded-Proto") + "://" + host + r.RequestURI
		w.Header().Set("Location", PortalURL.String())
		w.WriteHeader(http.StatusFound)
		if r.Method != "HEAD" {
			t := template.New("foo")
			t, _ = t.Parse(`
<html>
<head><title>302 Moved Temporarily</title></head>
<body>
	<h1>Moved</h1>
		<p>The document has moved <a href="{{.String}}">here</a>.</p>
		<!--<?xml version="1.0" encoding="UTF-8"?>
			<WISPAccessGatewayParam xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.wballiance.net/wispr/wispr_2_0.xsd">
				<Redirect>
					<MessageType>100</MessageType>
					<ResponseCode>0</ResponseCode>
					<AccessProcedure>1.0</AccessProcedure>
					<VersionLow>1.0</VersionLow>
					<VersionHigh>2.0</VersionHigh>
					<AccessLocation>CDATA[[isocc=,cc=,ac=,network=PacketFence,]]</AccessLocation>
					<LocationName>CDATA[[PacketFence]]</LocationName>
					<LoginURL>{{.String}}</LoginURL>
				</Redirect>
			</WISPAccessGatewayParam>-->
	</body>
</html>`)
			t.Execute(w, &PortalURL)
		}
		log.LoggerWContext(ctx).Debug(fmt.Sprintln(host, "REDIRECT"))
		return
	}
	if !p.checkEndpointList(ctx, host) {
		log.LoggerWContext(ctx).Info(fmt.Sprintln(host, "FORBIDDEN host in blacklist"))
		w.WriteHeader(http.StatusForbidden)
		return
	}
	log.LoggerWContext(ctx).Debug(fmt.Sprintln(host, "REVERSE"))

	p.reverse(ctx, w, r, host)
}

// Configure add default target in the deny list
func (p *Proxy) Configure(ctx context.Context) {
	p.addToEndpointList(ctx, "localhost")
	p.addToEndpointList(ctx, "127.0.0.1")

	db, err := db.DbFromConfig(ctx)
	sharedutils.CheckError(err)
	p.Db = db

	p.IP4log, err = p.Db.Prepare("select mac from ip4log where ip = ? AND tenant_id = ?")
	if err != nil {
		fmt.Fprintf(os.Stderr, "httpd.dispatcher: database ip4log prepared statement error: %s", err)
	}

	p.IP6log, err = p.Db.Prepare("select mac from ip6log where ip = ? AND tenant_id = ?")
	if err != nil {
		fmt.Fprintf(os.Stderr, "pfdns: database ip6log prepared statement error: %s", err)
	}

	p.ParkingSecurityEvent, err = p.Db.Prepare("Select count(*) from security_event where security_event.security_event_id='1300003' and mac=? and status='open' AND tenant_id = ?")
	if err != nil {
		fmt.Fprintf(os.Stderr, "httpd.dispatcher: database security_event prepared statement error: %s", err)
	}
	p.apiClient = unifiedapiclient.NewFromConfig(ctx)
}

func (p *passthrough) readConfig(ctx context.Context) {
	fencing := pfconfigdriver.Config.PfConf.Fencing
	general := pfconfigdriver.Config.PfConf.General
	portal := pfconfigdriver.Config.PfConf.CaptivePortal

	var scheme string

	p.proxypassthrough = make([]*regexp.Regexp, 0)
	for _, v := range fencing.ProxyPassthroughs {
		p.addFqdnToList(ctx, v)
	}

	p.detectionmechanisms = make([]*regexp.Regexp, 0)
	for _, v := range portal.DetectionMecanismUrls {
		p.addDetectionMechanismsToList(ctx, v)
	}

	p.DetectionMecanismBypass = portal.DetectionMecanismBypass == "enabled"

	rgx, _ := regexp.Compile("CaptiveNetworkSupport")
	p.URIException = rgx

	if portal.SecureRedirect == "enabled" {
		p.SecureRedirect = true
		scheme = "https"
	} else {
		p.SecureRedirect = false
		scheme = "http"
	}

	index := 0

	var interfaces pfconfigdriver.ListenInts
	pfconfigdriver.FetchDecodeSocket(ctx, &interfaces)

	var keyConfNet pfconfigdriver.PfconfigKeys
	keyConfNet.PfconfigNS = "config::Network"
	keyConfNet.PfconfigHostnameOverlay = "yes"
	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfNet)

	var NetIndexDefault net.IPNet
	var portalURLDefault url.URL

	p.PortalURL = make(map[int]map[*net.IPNet]*url.URL)

	for _, key := range keyConfNet.Keys {
		var NetIndex net.IPNet
		var portalURL url.URL

		var portalUrl fqdn
		portalUrl.FQDN = make(map[*net.IPNet]*url.URL)

		var ConfNet pfconfigdriver.NetworkConf
		ConfNet.PfconfigHashNS = key
		pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)

		var portal string
		if ConfNet.PortalFQDN != "" {
			portal = ConfNet.PortalFQDN
		} else {
			portal = general.Hostname + "." + general.Domain
		}
		portalURL.Host = portal
		portalURL.Path = "/captive-portal"
		portalURL.Scheme = scheme

		NetIndex.Mask = net.IPMask(net.ParseIP(ConfNet.Netmask))
		NetIndex.IP = net.ParseIP(key)

		p.PortalURL[index] = make(map[*net.IPNet]*url.URL)
		p.PortalURL[index][&NetIndex] = &portalURL
		index++
	}
	NetIndexDefault.Mask = net.IPMask(net.IPv4zero)
	NetIndexDefault.IP = net.IPv4zero

	portalURLDefault.Host = general.Hostname + "." + general.Domain
	portalURLDefault.Path = "/captive-portal"
	portalURLDefault.Scheme = scheme

	p.PortalURL[index] = make(map[*net.IPNet]*url.URL)

	p.PortalURL[index][&NetIndexDefault] = &portalURLDefault

}

// newProxyPassthrough instantiate a passthrough and return it
func newProxyPassthrough(ctx context.Context) *passthrough {
	var p passthrough
	return &p
}

// addFqdnToList add all the passthrough fqdn in a list
func (p *passthrough) addFqdnToList(ctx context.Context, r string) error {
	rgx, err := regexp.Compile(r)
	if err == nil {
		p.mutex.Lock()
		p.proxypassthrough = append(p.proxypassthrough, rgx)
		p.mutex.Unlock()
	}
	return err
}

// addDetectionMechanismsToList add all detection mechanisms in a list
func (p *passthrough) addDetectionMechanismsToList(ctx context.Context, r string) error {
	rgx, err := regexp.Compile(r)
	if err == nil {
		p.mutex.Lock()
		p.detectionmechanisms = append(p.detectionmechanisms, rgx)
		p.mutex.Unlock()
	}
	return err
}

// checkProxyPassthrough compare the host to the list of regex
func (p *passthrough) checkProxyPassthrough(ctx context.Context, e string) bool {
	if p.proxypassthrough == nil {
		return false
	}

	for _, rgx := range p.proxypassthrough {
		if rgx.MatchString(e) {
			return true
		}
	}
	return false
}

// checkDetectionMechanisms compare the url to the detection mechanisms regex
func (p *passthrough) checkDetectionMechanisms(ctx context.Context, e string) bool {
	if p.detectionmechanisms == nil {
		return false
	}

	for _, rgx := range p.detectionmechanisms {
		if rgx.MatchString(e) {
			return true
		}
	}
	return false
}

// HasSecurityEvents search for parking security event
func (p *Proxy) HasSecurityEvents(ctx context.Context, mac string) bool {
	securityEvent := false
	var securityEventCount int
	err := p.ParkingSecurityEvent.QueryRow(mac, 1).Scan(&securityEventCount)
	if err != nil {
		fmt.Fprintf(os.Stderr, "httpd.dispatcher: HasSecurityEvent %s %s\n", mac, err)
	} else if securityEventCount != 0 {
		securityEvent = true
	}

	return securityEvent
}

// IP2Mac search the mac associated to the ip
func (p *Proxy) IP2Mac(ctx context.Context, ip string) (string, error) {
	var (
		mac string
		err error
	)
	srcIP := net.ParseIP(ip)

	if sharedutils.IsIPv4(srcIP) {
		err = p.IP4log.QueryRow(ip, TenantID).Scan(&mac)
	} else {
		err = p.IP6log.QueryRow(ip, TenantID).Scan(&mac)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "httpd.dispatcher: Ip2Mac mac for %s not found %s\n", ip, err)
	}

	return mac, err
}

func (p *Proxy) handleParking(ctx context.Context, w http.ResponseWriter, r *http.Request) {
	var ipAddress string

	fwdAddress := r.Header.Get("X-Forwarded-For")
	if fwdAddress != "" {

		ipAddress = fwdAddress

		// If we got an array... grab the first IP
		ips := strings.Split(fwdAddress, ", ")
		if len(ips) > 1 {
			ipAddress = ips[0]
		}
	}

	if ipAddress != "" {
		MAC, err := p.IP2Mac(ctx, ipAddress)

		if err == nil {
			if p.HasSecurityEvents(ctx, MAC) {
				if r.RequestURI == "/release-parking" {
					reqURL := r.URL
					// Call the API
					err = p.APIUnpark(ctx, MAC, ipAddress)
					if err == nil {
						reqURL.Path = "/back-on-network.html"
					} else {
						reqURL.Path = "/max-attempts.html"
					}
					r.URL = reqURL
				}
				log.LoggerWContext(ctx).Info("Parking detected for " + MAC)
				p.reverse(ctx, w, r, "127.0.0.1:5252")
			}
		}
	}
}

func (p *Proxy) reverse(ctx context.Context, w http.ResponseWriter, r *http.Request, host string) {

	rp := httputil.NewSingleHostReverseProxy(&url.URL{
		Scheme: "http",
		Host:   host,
	})

	// Uses most defaults of http.DefaultTransport with more aggressive timeouts
	rp.Transport = &http.Transport{
		Proxy: http.ProxyFromEnvironment,
		DialContext: (&net.Dialer{
			Timeout:   2 * time.Second,
			KeepAlive: 2 * time.Second,
			DualStack: true,
		}).DialContext,
		MaxIdleConns:          100,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   2 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
	}

	t := time.Now()

	// Pass the context in the request
	r = r.WithContext(ctx)
	rp.ServeHTTP(w, r)
	log.LoggerWContext(ctx).Info(fmt.Sprintln(host, time.Since(t)))
}

// APIUnpark use to unpark a device
func (p *Proxy) APIUnpark(ctx context.Context, mac string, ip string) error {

	var raw json.RawMessage

	payload := map[string]string{"ip": ip}
	data, err := json.Marshal(payload)

	err = p.apiClient.CallWithStringBody(ctx, "POST", "/api/v1/node/"+mac+"/unpark", string(data), &raw)
	if err != nil {
		log.LoggerWContext(ctx).Error("API error: " + err.Error())
		return err
	}

	if raw == nil {
		log.LoggerWContext(ctx).Warn("Empty response from " + "POST" + " /api/v1/" + mac + "/unpark")
		return errors.New("Empty response  from " + "POST" + " /api/v1/" + mac + "/unpark")
	}
	return nil
}
