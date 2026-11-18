package uiplugins

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"io/fs"
	"net"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/inverse-inc/go-utils/log"
)

// CAFile holds the certificates of the authorities that sign the plugin
// services certificates, in addition to the system ones (optional, PEM).
//
// It is read once, when the first plugin is contacted: after adding or
// rotating it, restart api-frontend (the process serving /api/v1/plugins and
// /api/v1/plugin/<name>/*). The file loaded, or its absence, is logged then.
const CAFile = "/usr/local/pf/conf/ssl/ui_plugins_ca.pem"

// RootCAs are the authorities a plugin service certificate must chain to: the
// system ones and CAFile. A variable for the tests.
var RootCAs = func() *x509.CertPool {
	ctx := context.Background()
	pool, err := x509.SystemCertPool()
	if err != nil || pool == nil {
		pool = x509.NewCertPool()
	}
	pem, err := os.ReadFile(CAFile)
	switch {
	case errors.Is(err, fs.ErrNotExist):
		log.LoggerWContext(ctx).Info("UI plugins: no " + CAFile + ", the plugin certificates must chain to the system authorities")
	case err != nil:
		log.LoggerWContext(ctx).Warn("UI plugins: unable to read " + CAFile + ", only the system authorities are trusted: " + err.Error())
	case !pool.AppendCertsFromPEM(pem):
		log.LoggerWContext(ctx).Warn("UI plugins: no certificate in " + CAFile + ", only the system authorities are trusted")
	default:
		log.LoggerWContext(ctx).Info("UI plugins: trusting the authorities of " + CAFile + " and the system ones (restart api-frontend after changing it)")
	}
	return pool
}

// newTransport is the transport to the plugin services: no proxy from the
// environment, a short dial, TLS verified against RootCAs, no compression
// asked by the client passed through (the answer is checked as JSON)
func newTransport() *http.Transport {
	return newTransportWith(30 * time.Second)
}

// newTransportWith is newTransport waiting up to responseHeaderTimeout for
// the headers of an answer
func newTransportWith(responseHeaderTimeout time.Duration) *http.Transport {
	return &http.Transport{
		Proxy:                 nil,
		DialContext:           (&net.Dialer{Timeout: 3 * time.Second}).DialContext,
		TLSClientConfig:       &tls.Config{RootCAs: RootCAs(), MinVersion: tls.VersionTLS12},
		TLSHandshakeTimeout:   3 * time.Second,
		ResponseHeaderTimeout: responseHeaderTimeout,
		MaxIdleConnsPerHost:   4,
		IdleConnTimeout:       90 * time.Second,
	}
}

var (
	sharedTransportOnce sync.Once
	sharedTransport     http.RoundTripper
)

// pluginTransport replaces the shared transport in the tests
var pluginTransport http.RoundTripper

// transport is the one transport of the manifest fetches and of the proxy:
// one pool of idle connections per plugin service, the CA pool loaded once,
// when the first plugin is contacted
func transport() http.RoundTripper {
	if pluginTransport != nil {
		return pluginTransport
	}
	sharedTransportOnce.Do(func() { sharedTransport = newTransport() })
	return sharedTransport
}

var (
	passthroughTransportOnce sync.Once
	passthroughTransport     http.RoundTripper
)

// passthroughRoundTripper sends the requests to the bundle plugins: their
// calls may take up to MaxPassthroughTimeout before answering (the context of
// the request bounds each one to its bundle.timeout)
type passthroughRoundTripper struct{}

func (passthroughRoundTripper) RoundTrip(r *http.Request) (*http.Response, error) {
	if pluginTransport != nil {
		return pluginTransport.RoundTrip(r)
	}
	passthroughTransportOnce.Do(func() { passthroughTransport = newTransportWith(MaxPassthroughTimeout * time.Second) })
	return passthroughTransport.RoundTrip(r)
}

// roundTripper sends the requests through transport()
type roundTripper struct{}

func (roundTripper) RoundTrip(r *http.Request) (*http.Response, error) {
	return transport().RoundTrip(r)
}

var errRedirect = errors.New("a plugin service cannot redirect")

// newClient is the client of the manifest fetches, on the shared transport:
// its own timeout, redirects are refused
func newClient(timeout time.Duration) *http.Client {
	return &http.Client{
		Timeout:       timeout,
		Transport:     roundTripper{},
		CheckRedirect: func(*http.Request, []*http.Request) error { return errRedirect },
	}
}
