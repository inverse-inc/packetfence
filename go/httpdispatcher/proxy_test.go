package httpdispatcher

import (
	"bytes"
	"context"
	"net/http/httptest"
	"net/url"
	"os"
	"regexp"
	"testing"
)

var testproxy Proxy
var ctx = context.Background()

func TestMain(m *testing.M) {
	passThrough = newProxyPassthrough(ctx)
	rgx, _ := regexp.Compile("www.padl.com")
	passThrough.proxypassthrough = append(passThrough.proxypassthrough, rgx)
	rgx, _ = regexp.Compile("www.gstatic.com/generate_204")
	passThrough.detectionmechanisms = append(passThrough.detectionmechanisms, rgx)
	passThrough.DetectionMecanismBypass = true
	rgx, _ = regexp.Compile("CaptiveNetworkSupport")
	passThrough.URIException = rgx

	var portalURL url.URL
	var wisprURL url.URL

	portalURL.Host = "www.packetfence.org"
	portalURL.Path = "/captive-portal"
	portalURL.Scheme = "http"

	wisprURL.Host = "www.packetfence.org"
	wisprURL.Path = "/wispr"
	wisprURL.Scheme = "http"

	passThrough.WisprURL = &wisprURL
	passThrough.PortalURL = &portalURL
	testproxy.addToEndpointList(ctx, "127.0.0.1")
	os.Exit(m.Run())
}

func TestSimpleRedirect(t *testing.T) {
	req := httptest.NewRequest("GET", "http://www.inverse.ca", bytes.NewBuffer([]byte("")))
	recorder := httptest.NewRecorder()
	testproxy.ServeHTTP(recorder, req)
	if recorder.Code != 302 {
		t.Fatalf("Received non-302 response: %d\n", recorder.Code)
	}
}

func TestSimpleNotImplemented(t *testing.T) {
	req := httptest.NewRequest("POST", "http://www.packetfence.org", bytes.NewBuffer([]byte("")))
	recorder := httptest.NewRecorder()
	testproxy.ServeHTTP(recorder, req)
	if recorder.Code != 501 {
		t.Fatalf("Received non-501 response: %d\n", recorder.Code)
	}
}

func TestSimpleProxy(t *testing.T) {
	req := httptest.NewRequest("GET", "http://example.com", bytes.NewBuffer([]byte("")))
	req.Host = "example.com"
	recorder := httptest.NewRecorder()
	testproxy.ServeHTTP(recorder, req)
	if recorder.Code != 200 {
		t.Fatalf("Received non-200 response: %d\n", recorder.Code)
	}
}
