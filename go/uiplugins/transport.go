package uiplugins

import (
	"crypto/tls"
	"crypto/x509"
	"errors"
	"net"
	"net/http"
	"os"
	"time"
)

// CAFile holds the certificates of the authorities that sign the plugin
// services certificates, in addition to the system ones (optional, PEM)
const CAFile = "/usr/local/pf/conf/ssl/ui_plugins_ca.pem"

// RootCAs are the authorities a plugin service certificate must chain to: the
// system ones and CAFile. A variable for the tests.
var RootCAs = func() *x509.CertPool {
	pool, err := x509.SystemCertPool()
	if err != nil || pool == nil {
		pool = x509.NewCertPool()
	}
	if pem, err := os.ReadFile(CAFile); err == nil {
		pool.AppendCertsFromPEM(pem)
	}
	return pool
}

// newTransport is the transport to the plugin services: no proxy from the
// environment, a short dial, TLS verified against RootCAs, no compression
// asked by the client passed through (the answer is checked as JSON)
func newTransport() *http.Transport {
	return &http.Transport{
		Proxy:                 nil,
		DialContext:           (&net.Dialer{Timeout: 3 * time.Second}).DialContext,
		TLSClientConfig:       &tls.Config{RootCAs: RootCAs(), MinVersion: tls.VersionTLS12},
		TLSHandshakeTimeout:   3 * time.Second,
		ResponseHeaderTimeout: 30 * time.Second,
		MaxIdleConnsPerHost:   4,
		IdleConnTimeout:       90 * time.Second,
	}
}

var errRedirect = errors.New("a plugin service cannot redirect")

// newClient is the client of the manifest fetches: redirects are refused
func newClient(timeout time.Duration) *http.Client {
	return &http.Client{
		Timeout:       timeout,
		Transport:     newTransport(),
		CheckRedirect: func(*http.Request, []*http.Request) error { return errRedirect },
	}
}
