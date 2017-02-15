package main

import (
	"bufio"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"regexp"
	"sync"
	"text/template"
	"time"

	"bitbucket.org/oeufdure/pfconfigdriver"
	"github.com/davecgh/go-spew/spew"
	"github.com/patrickmn/go-cache"
	"gopkg.in/redis.v5"
)

type proxy struct {
	requestLogger     *log.Logger
	endpointWhiteList []*regexp.Regexp
	endpointBlackList []*regexp.Regexp
	mutex             sync.Mutex
}

type passthrough struct {
	proxypassthrough        []*regexp.Regexp
	detectionmechanisms     []*regexp.Regexp
	DetectionMecanismBypass string
	mutex                   sync.Mutex
	WisprURL                *url.URL
	PortalURL               *url.URL
	Cache                   *cache.Cache
	URIException            *regexp.Regexp
	SecureRedirect          bool
}

var passThrough *passthrough

// newProxy creates a new instance of proxy.
// It sets request logger using rLogPath as output file or os.Stdout by default.
// If whitePath of blackPath is not empty they are parsed to set endpoint lists.
func newProxy(rLogPath string, whitePath string, blackPath string) *proxy {
	var p proxy
	var l *log.Logger

	if rLogPath != "" {
		f, err := os.OpenFile(rLogPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
		if err != nil {
			log.Fatalln(err)
		}
		defer f.Close()
		l = log.New(f, "REQUEST: ", log.Ldate|log.Ltime)
	} else {
		l = log.New(os.Stdout, "REQUEST: ", log.Ldate|log.Ltime)
	}
	p.requestLogger = l

	if whitePath != "" {
		err := p.addEndpointListFromFile(whitePath, true)
		if err != nil {
			log.Fatalln(err)
		}
	}
	if blackPath != "" {
		err := p.addEndpointListFromFile(blackPath, false)
		if err != nil {
			log.Fatalln(err)
		}
	}
	passThrough = newProxyPassthrough()
	passThrough.readConfig()
	spew.Dump(passThrough)
	return &p
}

// addToEndpointListFromFile reads file line by line and calls
// addToEndpointList for each
// use t to choose list type: true for whitelist false for blacklist
func (p *proxy) addEndpointListFromFile(path string, t bool) error {
	f, err := os.Open(path)
	if err == nil {
		defer f.Close()
		s := bufio.NewScanner(f)
		for s.Scan() {
			err = p.addToEndpointList(s.Text(), t)
			if err != nil {
				return err
			}
		}
	}
	return err
}

// addToEndpointList compiles regex and adds it to an endpointList
// if regex is valid
// use t to choose list type: true for whitelist false for blacklist
func (p *proxy) addToEndpointList(r string, t bool) error {
	rgx, err := regexp.Compile(r)
	if err == nil {
		p.mutex.Lock()
		if t {
			p.endpointWhiteList = append(p.endpointWhiteList, rgx)
		} else {
			p.endpointBlackList = append(p.endpointBlackList, rgx)
		}
		p.mutex.Unlock()
	}
	return err
}

// checkEndpointList looks if r is in whitelist or blackllist
// returns true if endpoint is allowed
func (p *proxy) checkEndpointList(e string) bool {
	if p.endpointBlackList == nil && p.endpointWhiteList == nil {
		return true
	}

	for _, rgx := range p.endpointBlackList {
		if rgx.MatchString(e) {
			return false
		}
	}

	if p.endpointWhiteList == nil {
		return true
	}
	for _, rgx := range p.endpointWhiteList {
		if rgx.MatchString(e) {
			return true
		}
	}
	return false
}

// ServeHTTP satisfy HandlerFunc interface and
// log, authorize and forward requests
func (p *proxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
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

	if passThrough.checkParking(r.Header.Get("X-Forwarded-For")) {
		//p.requestLogger.Println(host, "PARKING", r.URL)
		rp := httputil.NewSingleHostReverseProxy(&url.URL{
			Scheme: "http",
			Host:   "127.0.0.1:5252",
		})
		t := time.Now()
		rp.ServeHTTP(w, r)
		p.requestLogger.Println(host, time.Since(t))
		return
	}

	if !(passThrough.checkProxyPassthrough(host) || ((passThrough.checkDetectionMechanisms(fqdn.String()) || passThrough.URIException.MatchString(r.RequestURI)) && passThrough.DetectionMecanismBypass == "enabled")) {
		if r.Method != "GET" {
			//p.requestLogger.Println(host, "FORBIDDEN")
			w.WriteHeader(http.StatusNotImplemented)
			return
		}

		if (passThrough.checkDetectionMechanisms(fqdn.String()) || passThrough.URIException.MatchString(r.RequestURI)) && passThrough.SecureRedirect {
			passThrough.PortalURL.Scheme = "http"
		}
		//p.requestLogger.Println(host, "Redirect to the portal")
		passThrough.PortalURL.RawQuery = "destination_url=" + r.Header.Get("X-Forwarded-Proto") + "://" + host + r.RequestURI
		w.Header().Set("Location", passThrough.PortalURL.String())
		w.WriteHeader(http.StatusFound)
		t := template.New("foo")
		t, _ = t.Parse("<html><head><title>302 Moved Temporarily</title></head><body><h1>Moved</h1><p>The document has moved <a href=\"{{.PortalURL.String}}\">here</a>.</p><!--<?xml version=\"1.0\" encoding=\"UTF-8\"?><WISPAccessGatewayParam xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:noNamespaceSchemaLocation=\"http://www.wballiance.net/wispr/wispr_2_0.xsd\"><Redirect><MessageType>100</MessageType><ResponseCode>0</ResponseCode><AccessProcedure>1.0</AccessProcedure><VersionLow>1.0</VersionLow><VersionHigh>2.0</VersionHigh><AccessLocation>CDATA[[isocc=,cc=,ac=,network=PacketFence,]]</AccessLocation><LocationName>CDATA[[PacketFence]]</LocationName><LoginURL>{{.WisprUrl.String}}</LoginURL></Redirect></WISPAccessGatewayParam>--></body></html>")
		t.Execute(w, passThrough)

		//spew.Dump(r)
		//spew.Dump(r.Header.Get("X-Forwarded-Proto"))
		//p.requestLogger.Println(host, "REDIRECT")
		return
	}
	// if !p.checkEndpointList(host) {
	// 	p.requestLogger.Println(host, "FORBIDDEN")
	// 	w.WriteHeader(http.StatusForbidden)
	// 	return
	// }
	//p.requestLogger.Println(host, "REVERSE")
	rp := httputil.NewSingleHostReverseProxy(&url.URL{
		Scheme: "http",
		Host:   host,
	})
	t := time.Now()
	rp.ServeHTTP(w, r)
	p.requestLogger.Println(host, time.Since(t))
}

// run add localhost to blacklist and launch proxy
func (p *proxy) run(port string) {
	p.addToEndpointList("localhost", false)
	p.addToEndpointList("127.0.0.1", false)
	log.Fatal(http.ListenAndServe(":"+port, p))
}

func (p *passthrough) readConfig() {
	var trapping pfconfigdriver.PfconfigTrapping
	var portal pfconfigdriver.PfconfigCaptivePortal
	var general pfconfigdriver.PfconfigGeneral
	var scheme string

	pfconfigdriver.FetchDecodeSocketStruct(ctx, &trapping)
	pfconfigdriver.FetchDecodeSocketStruct(ctx, &portal)
	pfconfigdriver.FetchDecodeSocketStruct(ctx, &general)

	for _, v := range trapping.ProxyPassthroughs {
		p.addFqdnToList(v)
	}

	for _, v := range portal.DetectionMecanismUrls {
		p.addDetectionMechanismsToList(v)
	}

	p.Cache = cache.New(3*time.Second, 1*time.Second)
	p.DetectionMecanismBypass = portal.DetectionMecanismBypass
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
	wisprURL.Path = "/captive-portal"
	wisprURL.Scheme = scheme

	p.WisprURL = &wisprURL
	//general.Hostname + "." + general.Domain + "/wispr"
	p.PortalURL = &portalURL
	//general.Hostname + "." + general.Domain + "/captive-portal"

}

func newProxyPassthrough() *passthrough {
	var p passthrough
	return &p
}

func (p *passthrough) addFqdnToList(r string) error {
	rgx, err := regexp.Compile(r)
	if err == nil {
		p.mutex.Lock()
		p.proxypassthrough = append(p.proxypassthrough, rgx)
		p.mutex.Unlock()
	}
	return err
}

func (p *passthrough) addDetectionMechanismsToList(r string) error {
	rgx, err := regexp.Compile(r)
	if err == nil {
		p.mutex.Lock()
		p.detectionmechanisms = append(p.detectionmechanisms, rgx)
		p.mutex.Unlock()
	}
	return err
}

func (p *passthrough) checkProxyPassthrough(e string) bool {
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

func (p *passthrough) checkDetectionMechanisms(e string) bool {
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

func (p *passthrough) checkParking(e string) bool {
	val, found := p.Cache.Get(e)
	if found == false {
		client := redis.NewClient(&redis.Options{
			Addr:     "localhost:6379",
			Password: "", // no password set
			DB:       0,  // use default DB
		})
		val, error := client.Get(e).Result()
		if error != nil {
			p.Cache.Set(e, false, cache.DefaultExpiration)
			//panic(err)
			return false
		}
		if val == "1" {
			p.Cache.Set(e, true, cache.DefaultExpiration)
			return true
		} else {
			p.Cache.Set(e, false, cache.DefaultExpiration)
			return false
		}
	} else if val == true {
		return true
	} else {
		return false
	}
}
