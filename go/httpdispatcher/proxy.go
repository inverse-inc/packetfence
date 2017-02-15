package httpdispatcher

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"regexp"
	"sync"
	"text/template"
	"time"

	"github.com/fingerbank/processor/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type Proxy struct {
	endpointWhiteList []*regexp.Regexp
	endpointBlackList []*regexp.Regexp
	mutex             sync.Mutex
}

type passthrough struct {
	proxypassthrough        []*regexp.Regexp
	detectionmechanisms     []*regexp.Regexp
	DetectionMecanismBypass bool
	mutex                   sync.Mutex
	WisprURL                *url.URL
	PortalURL               *url.URL
	//	Cache                   *cache.Cache
	URIException   *regexp.Regexp
	SecureRedirect bool
}

var passThrough *passthrough

// NewProxy creates a new instance of proxy.
// It sets request logger using rLogPath as output file or os.Stdout by default.
// If whitePath of blackPath is not empty they are parsed to set endpoint lists.
func NewProxy(ctx context.Context) *Proxy {
	var p Proxy

	passThrough = newProxyPassthrough(ctx)
	passThrough.readConfig(ctx)
	return &p
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

	//spew.Dump(fqdn.String())
	//spew.Dump(r)
	if host == "" {
		w.WriteHeader(http.StatusBadGateway)
		return
	}

	// if passThrough.checkParking(ctx, r.Header.Get("X-Forwarded-For")) {
	// 	log.LoggerWContext(ctx).Debug(fmt.Sprintln(host, "PARKING", r.URL))
	// 	rp := httputil.NewSingleHostReverseProxy(&url.URL{
	// 		Scheme: "http",
	// 		Host:   "127.0.0.1:5252",
	// 	})
	// 	t := time.Now()
	//
	// 	//Transfer current context in a shallow copy of the request
	// 	r = r.WithContext(ctx)
	// 	rp.ServeHTTP(w, r)
	// 	log.LoggerWContext(ctx).Info(fmt.Sprintln(host, time.Since(t)))
	// 	return
	// }

	if !(passThrough.checkProxyPassthrough(ctx, host) || ((passThrough.checkDetectionMechanisms(ctx, fqdn.String()) || passThrough.URIException.MatchString(r.RequestURI)) && passThrough.DetectionMecanismBypass)) {
		if r.Method != "GET" {
			log.LoggerWContext(ctx).Debug(fmt.Sprintln(host, "FORBIDDEN"))
			w.WriteHeader(http.StatusNotImplemented)
			return
		}

		if (passThrough.checkDetectionMechanisms(ctx, fqdn.String()) || passThrough.URIException.MatchString(r.RequestURI)) && passThrough.SecureRedirect {
			passThrough.PortalURL.Scheme = "http"
		}
		log.LoggerWContext(ctx).Debug(fmt.Sprintln(host, "Redirect to the portal"))
		passThrough.PortalURL.RawQuery = "destination_url=" + r.Header.Get("X-Forwarded-Proto") + "://" + host + r.RequestURI
		w.Header().Set("Location", passThrough.PortalURL.String())
		w.WriteHeader(http.StatusFound)
		t := template.New("foo")
		t, _ = t.Parse(`
<html>
<head><title>302 Moved Temporarily</title></head>
<body>
	<h1>Moved</h1>
		<p>The document has moved <a href=\"{{.PortalURL.String}}\">here</a>.</p>
		<!--<?xml version=\"1.0\" encoding=\"UTF-8\"?>
			<WISPAccessGatewayParam xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:noNamespaceSchemaLocation=\"http://www.wballiance.net/wispr/wispr_2_0.xsd\">
				<Redirect>
					<MessageType>100</MessageType>
					<ResponseCode>0</ResponseCode>
					<AccessProcedure>1.0</AccessProcedure>
					<VersionLow>1.0</VersionLow>
					<VersionHigh>2.0</VersionHigh>
					<AccessLocation>CDATA[[isocc=,cc=,ac=,network=PacketFence,]]</AccessLocation>
					<LocationName>CDATA[[PacketFence]]</LocationName>
					<LoginURL>{{.WisprUrl.String}}</LoginURL>
				</Redirect>
			</WISPAccessGatewayParam>-->
	</body>
</html>`)
		t.Execute(w, passThrough)

		//spew.Dump(r)
		//spew.Dump(r.Header.Get("X-Forwarded-Proto"))
		log.LoggerWContext(ctx).Debug(fmt.Sprintln(host, "REDIRECT"))
		return
	}
	if !p.checkEndpointList(ctx, host) {
		log.LoggerWContext(ctx).Info(fmt.Sprintln(host, "FORBIDDEN"))
		w.WriteHeader(http.StatusForbidden)
		return
	}
	log.LoggerWContext(ctx).Debug(fmt.Sprintln(host, "REVERSE"))
	rp := httputil.NewSingleHostReverseProxy(&url.URL{
		Scheme: "http",
		Host:   host,
	})
	t := time.Now()

	// Pass the context in the request
	r = r.WithContext(ctx)
	rp.ServeHTTP(w, r)
	log.LoggerWContext(ctx).Info(fmt.Sprintln(host, time.Since(t)))
}

// Configure add default target in teh deny list
func (p *Proxy) Configure(ctx context.Context, port string) {
	p.addToEndpointList(ctx, "localhost")
	p.addToEndpointList(ctx, "127.0.0.1")
}

func (p *passthrough) readConfig(ctx context.Context) {
	var trapping pfconfigdriver.PfConfTrapping
	var portal pfconfigdriver.PfConfCaptivePortal
	var general pfconfigdriver.PfConfGeneral
	var scheme string

	pfconfigdriver.FetchDecodeSocketStruct(ctx, &trapping)
	pfconfigdriver.FetchDecodeSocketStruct(ctx, &portal)
	pfconfigdriver.FetchDecodeSocketStruct(ctx, &general)

	for _, v := range trapping.ProxyPassthroughs {
		p.addFqdnToList(ctx, v)
	}

	for _, v := range portal.DetectionMecanismUrls {
		p.addDetectionMechanismsToList(ctx, v)
	}

	//p.Cache = cache.New(3*time.Second, 1*time.Second)

	p.DetectionMecanismBypass = portal.DetectionMecanismBypass
	if portal.DetectionMecanismBypass == "enabled" {
		p.DetectionMecanismBypass = true
	}
	if portal.DetectionMecanismBypass == "disabled" {
		p.DetectionMecanismBypass = false
	}
	rgx, _ := regexp.Compile("CaptiveNetworkSupport")
	p.URIException = rgx
	if portal.SecureRedirect == "enabled" {
		p.SecureRedirect = true
		scheme = "https"
	}
	if portal.SecureRedirect == "disabled" {
		p.SecureRedirect = false
		scheme = "http"
	}
	var portalURL url.URL
	var wisprURL url.URL

	portalURL.Host = general.Hostname + "." + general.Domain
	portalURL.Path = "/captive-portal"
	portalURL.Scheme = scheme

	wisprURL.Host = general.Hostname + "." + general.Domain
	wisprURL.Path = "/wispr"
	wisprURL.Scheme = scheme

	p.WisprURL = &wisprURL
	//general.Hostname + "." + general.Domain + "/wispr"
	p.PortalURL = &portalURL
	//general.Hostname + "." + general.Domain + "/captive-portal"

}

func newProxyPassthrough(ctx context.Context) *passthrough {
	var p passthrough
	return &p
}

func (p *passthrough) addFqdnToList(ctx context.Context, r string) error {
	rgx, err := regexp.Compile(r)
	if err == nil {
		p.mutex.Lock()
		p.proxypassthrough = append(p.proxypassthrough, rgx)
		p.mutex.Unlock()
	}
	return err
}

func (p *passthrough) addDetectionMechanismsToList(ctx context.Context, r string) error {
	rgx, err := regexp.Compile(r)
	if err == nil {
		p.mutex.Lock()
		p.detectionmechanisms = append(p.detectionmechanisms, rgx)
		p.mutex.Unlock()
	}
	return err
}

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

// func (p *passthrough) checkParking(ctx context.Context, e string) bool {
// 	val, found := p.Cache.Get(e)
// 	if found == false {
// 		client := redis.NewClient(&redis.Options{
// 			Addr:     "localhost:6379",
// 			Password: "", // no password set
// 			DB:       0,  // use default DB
// 		})
// 		val, error := client.Get(e).Result()
// 		if error != nil {
// 			p.Cache.Set(e, false, cache.DefaultExpiration)
// 			//panic(err)
// 			return false
// 		}
// 		if val == "1" {
// 			p.Cache.Set(e, true, cache.DefaultExpiration)
// 			return true
// 		} else {
// 			p.Cache.Set(e, false, cache.DefaultExpiration)
// 			return false
// 		}
// 	} else if val == true {
// 		return true
// 	} else {
// 		return false
// 	}
// }
