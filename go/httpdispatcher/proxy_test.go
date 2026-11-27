package httpdispatcher

import (
	"bytes"
	"context"
	"net"
	"net/http/httptest"
	"net/url"
	"os"
	"regexp"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

var testproxy Proxy
var ctx = context.Background()

// pfconfigAvailable is whether pfconfig can be reached: the tests that build a
// Proxy (NewProxy) need it, the others don't
var pfconfigAvailable bool

// pfconfigReachable returns whether the pfconfig the pfconfigdriver would use answers
func pfconfigReachable() bool {
	network, address := "tcp", net.JoinHostPort(envOrDefault("PFCONFIG_TCP_HOST", "127.0.0.1"), envOrDefault("PFCONFIG_TCP_PORT", "44444"))
	if envOrDefault("PFCONFIG_PROTO", "tcp") == "unix" {
		network, address = "unix", "/usr/local/pf/var/run/pfconfig.sock"
		if os.Getenv("PFCONFIG_TESTING") != "" {
			address = "/usr/local/pf/var/run/pfconfig-test.sock"
		}
	}
	conn, err := net.DialTimeout(network, address, time.Second)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

func envOrDefault(name, value string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return value
}

func skipWithoutPfconfig(t *testing.T) {
	if !pfconfigAvailable {
		t.Skip("pfconfig is not reachable")
	}
}

func TestMain(m *testing.M) {
	pfconfigAvailable = pfconfigReachable()
	if pfconfigAvailable {
		pfconfigdriver.AddType[pfconfigdriver.PfConfFencing](ctx)
		pfconfigdriver.AddType[pfconfigdriver.PfConfGeneral](ctx)
		pfconfigdriver.AddType[pfconfigdriver.PfConfCaptivePortal](ctx)
		pfconfigdriver.AddType[pfconfigdriver.PfConfParking](ctx)
	}
	passThrough = newProxyPassthrough(ctx)
	passThrough.addFqdnToList(ctx, "captive.apple.com")
	passThrough.addDetectionMechanismsToList(ctx, "http://www.gstatic.com/generate_204")
	passThrough.DetectionMecanismBypass = true
	rgx, _ := regexp.Compile("CaptiveNetworkSupport")
	passThrough.URIException = rgx

	var portalURL url.URL
	var NetIndex net.IPNet
	passThrough.PortalURL = make(map[int]map[*net.IPNet]*url.URL)

	portalURL.Host = "www.packetfence.org"
	portalURL.Path = "/captive-portal"
	portalURL.Scheme = "http"

	NetIndex.Mask = net.IPMask(net.IPv4zero)
	NetIndex.IP = net.IPv4zero
	passThrough.PortalURL[0] = make(map[*net.IPNet]*url.URL)
	passThrough.PortalURL[0][&NetIndex] = &portalURL

	os.Exit(m.Run())
}

func TestSimpleRedirect(t *testing.T) {
	skipWithoutPfconfig(t)
	testproxy := NewProxy(ctx)
	req := httptest.NewRequest("GET", "http://www.inverse.ca", bytes.NewBuffer([]byte("")))
	recorder := httptest.NewRecorder()
	testproxy.ServeHTTP(recorder, req)
	if recorder.Code != 200 {
		t.Fatalf("Received non-302 response: %d\n", recorder.Code)
	}
}

func TestSimpleNotImplemented(t *testing.T) {
	skipWithoutPfconfig(t)
	testproxy := NewProxy(ctx)
	req := httptest.NewRequest("POST", "http://www.packetfence.org", bytes.NewBuffer([]byte("")))
	recorder := httptest.NewRecorder()
	testproxy.ServeHTTP(recorder, req)
	if recorder.Code != 501 {
		t.Fatalf("Received non-501 response: %d\n", recorder.Code)
	}
}

func TestSimpleProxy(t *testing.T) {
	skipWithoutPfconfig(t)
	testproxy := NewProxy(ctx)
	req := httptest.NewRequest("GET", "http://detectportal.firefox.com", bytes.NewBuffer([]byte("")))
	req.Host = "detectportal.firefox.com"
	recorder := httptest.NewRecorder()
	testproxy.ServeHTTP(recorder, req)
	if recorder.Code != 200 {
		t.Fatalf("Received non-200 response: %d\n", recorder.Code)
	}
}
