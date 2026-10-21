package acme

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// http01Client fetches the device's well-known challenge response. The
// identifier it connects to is chosen by whoever holds an ACME account,
// so the transport pins the destination (see newHTTP01Client) rather
// than trusting the URL: without that, a challenge is a free SSRF
// primitive against pfpki's own localhost API and anything else on the
// host. Exposed as a package variable so tests can swap it for a
// transport that returns canned responses without real networking.
var http01Client = newHTTP01Client()

// http01AllowedPorts are the only ports a challenge fetch, or a redirect
// it follows, may connect to. RFC 8555 §8.3 fixes the initial request
// to port 80; like Boulder we also follow redirects to 443.
var http01AllowedPorts = map[string]bool{"80": true, "443": true}

func newHTTP01Client() *http.Client {
	dialer := &net.Dialer{Timeout: 5 * time.Second}
	transport := &http.Transport{
		// Never route challenge fetches through an environment proxy: the
		// proxy would connect to attacker-chosen addresses on our behalf
		// and the checks in DialContext would be bypassed.
		Proxy: nil,
		DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			host, port, err := net.SplitHostPort(addr)
			if err != nil {
				return nil, err
			}
			if !http01AllowedPorts[port] {
				return nil, fmt.Errorf("http-01: port %s is not allowed", port)
			}
			ips, err := net.DefaultResolver.LookupIPAddr(ctx, host)
			if err != nil {
				return nil, err
			}
			// Dial the resolved address ourselves instead of handing the
			// name back to the dialer, so a rebinding resolver can't swap
			// in a forbidden address between the check and the connect.
			var lastErr error
			for _, ip := range ips {
				if !http01AllowedIP(ip.IP) {
					lastErr = fmt.Errorf("http-01: %s resolves to a non-routable address", host)
					continue
				}
				conn, err := dialer.DialContext(ctx, network, net.JoinHostPort(ip.IP.String(), port))
				if err == nil {
					return conn, nil
				}
				lastErr = err
			}
			if lastErr == nil {
				lastErr = fmt.Errorf("http-01: no address for %s", host)
			}
			return nil, lastErr
		},
		TLSHandshakeTimeout:   5 * time.Second,
		ResponseHeaderTimeout: 5 * time.Second,
		DisableKeepAlives:     true,
	}
	return &http.Client{
		Timeout:   10 * time.Second,
		Transport: transport,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			// RFC 8555 §8.3: the server SHOULD follow redirects; stdlib's
			// 10-hop cap matches the spec. Only http/https targets, and
			// DialContext re-checks the port and address on every hop.
			if len(via) >= 10 {
				return errors.New("http-01: too many redirects")
			}
			if req.URL.Scheme != "http" && req.URL.Scheme != "https" {
				return fmt.Errorf("http-01: redirect to %s:// is not allowed", req.URL.Scheme)
			}
			return nil
		},
	}
}

// http01AllowedIP reports whether a challenge fetch may connect to ip.
// Private (RFC 1918 / ULA) ranges are allowed, NAC devices usually live
// there, but anything that only makes sense from the pfpki host itself
// (loopback, link-local including cloud metadata, unspecified,
// multicast, broadcast) is refused.
func http01AllowedIP(ip net.IP) bool {
	if ip == nil {
		return false
	}
	if ip.IsUnspecified() || ip.IsLoopback() || ip.IsMulticast() ||
		ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() ||
		ip.IsInterfaceLocalMulticast() {
		return false
	}
	if v4 := ip.To4(); v4 != nil {
		if v4[0] == 0 || v4.Equal(net.IPv4bcast) {
			return false
		}
	}
	return true
}

// http01URL builds the RFC 8555 §8.3 challenge URL. The identifier is
// re-validated here even though new-order already did, so the URL can
// never carry a scheme, port, path or userinfo smuggled in the value.
// IPv6 literals are bracketed to form a valid authority.
func http01URL(identifier, token string) (string, error) {
	host := identifier
	if ip := net.ParseIP(identifier); ip != nil {
		if !http01AllowedIP(ip) {
			return "", fmt.Errorf("%q is not a routable unicast address", identifier)
		}
		if ip.To4() == nil {
			host = "[" + ip.String() + "]"
		}
	} else if err := validateDNSIdentifier(identifier); err != nil {
		return "", err
	}
	u := url.URL{Scheme: "http", Host: host, Path: "/.well-known/acme-challenge/" + token}
	return u.String(), nil
}

// http01Validate performs the RFC 8555 §8.3 verification: GET
// http://<identifier>/.well-known/acme-challenge/<token> and confirm
// the response body equals "<token>.<accountKeyThumbprint>". Returns
// nil on success; the returned error message is safe to surface in an
// ACME problem document.
//
// The spec mandates HTTP (not HTTPS) on port 80; we honor that for
// compatibility with off-the-shelf ACME clients. Reverse proxies in
// front of the device's responder are the operator's problem.
func http01Validate(ctx context.Context, identifier, token, thumbprint string) error {
	identifier = strings.TrimSpace(identifier)
	if identifier == "" {
		return errors.New("http-01: empty identifier")
	}
	if token == "" || thumbprint == "" {
		return errors.New("http-01: empty token or thumbprint")
	}
	target, err := http01URL(identifier, token)
	if err != nil {
		return fmt.Errorf("http-01: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, "GET", target, nil)
	if err != nil {
		return fmt.Errorf("http-01: build request: %w", err)
	}
	resp, err := http01Client.Do(req)
	if err != nil {
		return fmt.Errorf("http-01: fetch: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("http-01: HTTP %d from challenge URL", resp.StatusCode)
	}
	// Cap the body read so a hostile responder can't keep us reading
	// forever; the spec only ever expects a tiny `token.thumbprint`.
	body, err := io.ReadAll(io.LimitReader(resp.Body, 4096))
	if err != nil {
		return fmt.Errorf("http-01: read body: %w", err)
	}
	got := strings.TrimSpace(string(body))
	want := token + "." + thumbprint
	if got != want {
		return fmt.Errorf("http-01: key authorization mismatch")
	}
	return nil
}
