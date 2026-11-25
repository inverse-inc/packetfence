package httpdispatcher

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"html/template"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"regexp"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

// Proxy structure
type Proxy struct {
	mutex                sync.Mutex
	ParkingSecurityEvent *sql.Stmt // prepared statement for security_event
	IP4log               *sql.Stmt // prepared statement for ip4log queries
	IP6log               *sql.Stmt // prepared statement for ip6log queries
	Nodedb               *sql.Stmt // prepared statement for node queries
	Db                   *sql.DB
	apiClient            *unifiedapiclient.Client
	ShowParkingPortal    bool
}

type passthrough struct {
	proxypassthrough        *hostMatcher
	detectionmechanisms     []detectionMechanism
	mutex                   sync.Mutex
	PortalURL               map[int]map[*net.IPNet]*url.URL
	URIException            *regexp.Regexp
	OtherDomains            *hostMatcher
	DetectionMecanismBypass bool
	SecureRedirect          bool
	Wispr                   bool
}

type fqdn struct {
	FQDN map[*net.IPNet]*url.URL
}

type RFC7710bis struct {
	UserPortalURL    string `json:"user-portal-url"`
	VenueInfoURL     string `json:"venue-info-url,omitempty"`
	SecondsRemaining int    `json:"seconds-remaining,omitempty"`
	BytesRemaining   int    `json:"bytes-remaining,omitempty"`
	CanExtendSession bool   `json:"can-extend-session,omitempty"`
	Captive          bool   `json:"captive"`
}

var passThrough *passthrough

var successDBConnect = false

// NewProxy creates a new instance of proxy.
// It sets request logger using rLogPath as output file or os.Stdout by default.
// If whitePath of blackPath is not empty they are parsed to set endpoint lists.
func NewProxy(ctx context.Context) *Proxy {
	p := &Proxy{}

	passThrough = newProxyPassthrough(ctx)
	passThrough.readConfig(ctx)
	p.Configure(ctx)
	return p
}

// Refresh the configuration
func (p *Proxy) Refresh(ctx context.Context) {
	passThrough.readConfig(ctx)
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

	parking := p.handleParking(ctx, w, r)

	if r.URL.Path == "/rfc7710" {
		_, PortalURL := p.detectPortalURL(r)

		answer := RFC7710bis{}

		answer.Captive = true
		if p.DetectRegistrationStatus(ctx, w, r) {
			answer.Captive = false
		}
		answer.UserPortalURL = PortalURL.String()
		w.Header().Set("Cache-Control", "private")
		w.Header().Set("Content-Type", "application/captive+json")
		w.WriteHeader(http.StatusOK)
		if err := json.NewEncoder(w).Encode(&answer); err != nil {
			fmt.Println(err)
		}
		return
	}

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

	if !(passThrough.checkProxyPassthrough(ctx, host) || (passThrough.DetectionMecanismBypass && passThrough.checkDetectionRequest(ctx, host, r.URL.Path))) {
		if r.Method != "GET" && r.Method != "HEAD" {
			log.LoggerWContext(ctx).Debug(fmt.Sprintln(host, "FORBIDDEN"))
			w.WriteHeader(http.StatusNotImplemented)
			return
		}

		_, PortalURL := p.detectPortalURL(r)
		if passThrough.checkOtherDomains(ctx, fqdn.Host) {
			PortalURL.Host = fqdn.Host
		}

		log.LoggerWContext(ctx).Debug(fmt.Sprintln(host, "Redirect to the portal"))

		destURL, _ := url.Parse(r.URL.String())

		destURL.Scheme = r.Header.Get("X-Forwarded-Proto")
		if r.Referer() != "" {
			refererHost, err := url.Parse(r.Referer())
			if err != nil {
				destURL.Host = host
			} else {
				destURL.Host = refererHost.Hostname()
			}
		} else {
			destURL.Host = host
		}

		if parking {
			PortalURL.Path = ""
			PortalURL.RawQuery = ""
		}

		// Detect wispr user agent but exclude Apple stuff
		wispr := regexp.MustCompile(`(?i)wispr`)
		CaptiveNetworkSupport := regexp.MustCompile(`(?i)CaptiveNetworkSupport`)

		PortalURL.RawQuery = "destination_url=" + destURL.String()

		w.Header().Set("Location", PortalURL.String())
		t := template.New("redirect")
		if r.Method != "HEAD" {
			if (wispr.MatchString(r.UserAgent()) && !CaptiveNetworkSupport.MatchString(r.UserAgent())) || passThrough.Wispr {
				w.WriteHeader(http.StatusFound)
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

			} else {
				w.WriteHeader(http.StatusOK)

				t, _ = t.Parse(`
<html>
    <head>
        <meta http-equiv="refresh" content="0; url={{.String}}">
        <script type="text/javascript">
            window.location.replace('{{.String}}');
        </script>
    </head>
</html>`)
			}
			t.Execute(w, &PortalURL)
		}
		log.LoggerWContext(ctx).Debug(fmt.Sprintln(host, "REDIRECT"))
		return
	}
	log.LoggerWContext(ctx).Debug(fmt.Sprintln(host, "REVERSE"))

	p.reversePassthrough(ctx, w, r, host)
}

// Configure connects the proxy to the database and the API
// (the passthrough destinations are restricted by proxiedDestinationControl)
func (p *Proxy) Configure(ctx context.Context) {

	Database, err := db.DbFromConfig(ctx)
	for err != nil {
		if err != nil {
			log.LoggerWContext(ctx).Error(fmt.Sprintf("Failed to connect to the database: %s", err))
			time.Sleep(time.Duration(5) * time.Second)
		}

		Database, err = db.DbFromConfig(ctx)
	}

	for !successDBConnect {
		err = Database.Ping()
		if err != nil {
			log.LoggerWContext(ctx).Error(fmt.Sprintf("Failed to connect to the database: %s", err))
			time.Sleep(time.Duration(5) * time.Second)
		} else {
			successDBConnect = true
		}
	}

	p.Db = Database

	p.IP4log, err = p.Db.Prepare("select mac from ip4log where ip = ? ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "httpd.dispatcher: database ip4log prepared statement error: %s", err)
	}

	p.IP6log, err = p.Db.Prepare("select mac from ip6log where ip = ? ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "pfdns: database ip6log prepared statement error: %s", err)
	}

	p.ParkingSecurityEvent, err = p.Db.Prepare("Select count(*) from security_event where security_event.security_event_id='1300003' and mac=? and status='open' ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "httpd.dispatcher: database security_event prepared statement error: %s", err)
	}

	p.Nodedb, err = p.Db.Prepare("select node.status from node where mac = ?")
	if err != nil {
		fmt.Fprintf(os.Stderr, "httpd.dispatcher: database nodedb prepared statement error: %s", err)
	}

	p.apiClient = unifiedapiclient.NewFromConfig(ctx)

	parking := pfconfigdriver.GetType[pfconfigdriver.PfConfParking](ctx)

	p.ShowParkingPortal = sharedutils.IsEnabled(parking.ShowParkingPortal)

	go func() {
		for {
			err = p.Db.Ping()
			if err != nil {
				p.Db, err = db.DbFromConfig(ctx)
			}
			time.Sleep(time.Duration(5) * time.Second)
		}
	}()

}

func (p *passthrough) readConfig(ctx context.Context) {

	fencing := pfconfigdriver.GetType[pfconfigdriver.PfConfFencing](ctx)
	portal := pfconfigdriver.GetType[pfconfigdriver.PfConfCaptivePortal](ctx)
	general := pfconfigdriver.GetType[pfconfigdriver.PfConfGeneral](ctx)

	var scheme string

	p.proxypassthrough = newHostMatcher()
	for _, v := range fencing.ProxyPassthroughs {
		p.addFqdnToList(ctx, v)
	}

	p.detectionmechanisms = make([]detectionMechanism, 0)
	for _, v := range portal.DetectionMecanismUrls {
		p.addDetectionMechanismsToList(ctx, v)
	}

	p.OtherDomains = newHostMatcher()
	for _, v := range portal.OtherDomainNames {
		p.addOtherDomainsToList(ctx, v)
	}

	p.DetectionMecanismBypass = sharedutils.IsEnabled(portal.DetectionMecanismBypass)

	rgx, _ := regexp.Compile("CaptiveNetworkSupport")
	p.URIException = rgx

	p.SecureRedirect = sharedutils.IsEnabled(portal.SecureRedirect)
	if p.SecureRedirect {
		scheme = "https"
	} else {
		scheme = "http"
	}

	p.Wispr = sharedutils.IsEnabled(portal.WisprRedirection)

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

// addFqdnToList add a passthrough host name (or *.domain) to the passthroughs
func (p *passthrough) addFqdnToList(ctx context.Context, r string) error {
	p.mutex.Lock()
	defer p.mutex.Unlock()
	if p.proxypassthrough == nil {
		p.proxypassthrough = newHostMatcher()
	}
	p.proxypassthrough.add(r)
	return nil
}

// addDetectionMechanismsToList add a detection mechanism URL to the detection mechanisms
func (p *passthrough) addDetectionMechanismsToList(ctx context.Context, r string) error {
	d, err := newDetectionMechanism(r)
	if err != nil {
		log.LoggerWContext(ctx).Warn(fmt.Sprintf("Ignoring the detection mechanism URL %q: %s", r, err))
		return err
	}
	p.mutex.Lock()
	p.detectionmechanisms = append(p.detectionmechanisms, d)
	p.mutex.Unlock()
	return nil
}

// addOtherDomainsToList add a domain name (or *.domain) to the other domain names of the portal
func (p *passthrough) addOtherDomainsToList(ctx context.Context, r string) error {
	p.mutex.Lock()
	defer p.mutex.Unlock()
	if p.OtherDomains == nil {
		p.OtherDomains = newHostMatcher()
	}
	p.OtherDomains.add(r)
	return nil
}

// checkProxyPassthrough returns whether the host is a passthrough
func (p *passthrough) checkProxyPassthrough(ctx context.Context, host string) bool {
	return p.proxypassthrough.match(host)
}

// checkDetectionMechanisms returns whether the request (host and path) is for a detection mechanism
func (p *passthrough) checkDetectionMechanisms(ctx context.Context, host, path string) bool {
	for _, d := range p.detectionmechanisms {
		if d.match(host, path) {
			return true
		}
	}
	return false
}

// checkDetectionRequest returns whether the request is for a detection
// mechanism, or for a host of a detection mechanism with a path matching the
// URIException
func (p *passthrough) checkDetectionRequest(ctx context.Context, host, path string) bool {
	if p.checkDetectionMechanisms(ctx, host, path) {
		return true
	}
	if p.URIException == nil || !p.URIException.MatchString(path) {
		return false
	}
	for _, d := range p.detectionmechanisms {
		if normHost(host) == d.host {
			return true
		}
	}
	return false
}

// checkOtherDomains returns whether the host is one of the other domain names of the portal
func (p *passthrough) checkOtherDomains(ctx context.Context, host string) bool {
	return p.OtherDomains.match(host)
}

// HasSecurityEvents search for parking security event
func (p *Proxy) HasSecurityEvents(ctx context.Context, mac string) bool {
	securityEvent := false
	var securityEventCount int
	err := p.ParkingSecurityEvent.QueryRowContext(ctx, mac).Scan(&securityEventCount)
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

	if srcIP != nil {
		if sharedutils.IsIPv4(srcIP) {
			err = p.IP4log.QueryRowContext(ctx, ip).Scan(&mac)
		} else {
			err = p.IP6log.QueryRowContext(ctx, ip).Scan(&mac)
		}
	} else {
		fmt.Fprintf(os.Stderr, "httpd.dispatcher: not able to fetch the source ip\n")
		err = errors.New("httpd.dispatcher: not able to fetch the source ip")
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "httpd.dispatcher: Ip2Mac mac for %s not found %s\n", ip, err)
	}

	return mac, err
}

func (p *Proxy) handleParking(ctx context.Context, w http.ResponseWriter, r *http.Request) bool {

	found, PortalURL := p.detectPortalURL(r)

	var ipAddress string
	reverseHost := "127.0.0.1:5252"

	rgx, _ := regexp.Compile("/common")

	ipAddress = p.getIP(ctx, r)

	MAC, err := p.IP2Mac(ctx, ipAddress)
	if err == nil {
		if p.HasSecurityEvents(ctx, MAC) && p.ShowParkingPortal {
			if found && (PortalURL.Host == r.Host) {
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
				if rgx.MatchString(r.RequestURI) {
					reverseHost = "127.0.0.1:8889"
				}
				log.LoggerWContext(ctx).Info("Parking detected for " + MAC)
				p.reverse(ctx, w, r, reverseHost)
			}
			return true
		}
		return false
	}
	return false
}

func (p *Proxy) detectPortalURL(r *http.Request) (bool, url.URL) {
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
	return found, PortalURL
}

func (p *Proxy) handleDetectionMechanismRegister(ctx context.Context, w http.ResponseWriter, r *http.Request, fqdn string) {
	var ipAddress string
	ipAddress = p.getIP(ctx, r)

	MAC, err := p.IP2Mac(ctx, ipAddress)

	if err == nil {
		if p.nodeIsReg(ctx, MAC) && passThrough.checkDetectionRequest(ctx, r.Host, r.URL.Path) {
			log.LoggerWContext(ctx).Info("Device register and match the portal detection mechanism for " + MAC)
			p.reversePassthrough(ctx, w, r, r.Host)
		}
	}
}

// nodeStatus search for status of the device
func (p *Proxy) nodeIsReg(ctx context.Context, mac string) bool {
	status := false
	var Status string
	err := p.Nodedb.QueryRow(mac).Scan(&Status)
	if err == nil {
		if Status == "reg" {
			status = true
		}
	}

	return status
}

func (p *Proxy) getIP(ctx context.Context, r *http.Request) string {

	var ipAddress string
	ipAddress = "0.0.0.0"
	fwdAddress := r.Header.Get("X-Forwarded-For")
	if fwdAddress != "" {

		ipAddress = fwdAddress

		// If we got an array... grab the first IP
		ips := strings.Split(fwdAddress, ", ")
		if len(ips) > 1 {
			ipAddress = ips[0]
		}
	}
	return ipAddress
}

// reversePassthrough proxies a passthrough (or detection mechanism) request:
// the passthroughs are http, so to port 80 of the host, and only to the
// allowed destinations
func (p *Proxy) reversePassthrough(ctx context.Context, w http.ResponseWriter, r *http.Request, host string) {
	p.reverseWithControl(ctx, w, r, net.JoinHostPort(normHost(host), "80"), proxiedDestinationControl)
}

// reverse proxies a request to a service of PacketFence (host:port)
func (p *Proxy) reverse(ctx context.Context, w http.ResponseWriter, r *http.Request, host string) {
	p.reverseWithControl(ctx, w, r, host, nil)
}

func (p *Proxy) reverseWithControl(ctx context.Context, w http.ResponseWriter, r *http.Request, host string, control func(network, address string, c syscall.RawConn) error) {

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
			Control:   control,
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
	log.LoggerWContext(ctx).Info(fmt.Sprintln("request proxied to "+host, time.Since(t)))
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

func (p *Proxy) DetectRegistrationStatus(ctx context.Context, w http.ResponseWriter, r *http.Request) bool {
	var ipAddress string
	ipAddress = p.getIP(ctx, r)

	if ipAddress != "" {
		MAC, err := p.IP2Mac(ctx, ipAddress)

		if err == nil {
			if p.nodeIsReg(ctx, MAC) {
				return true
			}
			return false
		}
		return false
	}
	return false
}
