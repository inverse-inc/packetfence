package api

import (
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
)

// The connector-remote API is reached through a tunnel that ends on a remote
// site: whatever answers there must be treated as untrusted. These helpers
// keep the answers of the remote out of the admin origin and the admin's
// credentials out of the remote.

// isWebsocketUpgrade reports whether r asks for a websocket upgrade.
func isWebsocketUpgrade(r *http.Request) bool {
	if !strings.EqualFold(r.Header.Get("Upgrade"), "websocket") {
		return false
	}
	for _, v := range r.Header.Values("Connection") {
		for _, token := range strings.Split(v, ",") {
			if strings.EqualFold(strings.TrimSpace(token), "upgrade") {
				return true
			}
		}
	}
	return false
}

// sameOriginWebsocket reports whether the Origin of a websocket upgrade is the
// host the browser reached the API on. Browsers always send it on websocket
// requests, so a missing Origin is refused too.
func sameOriginWebsocket(r *http.Request) bool {
	origin, err := url.Parse(r.Header.Get("Origin"))
	if err != nil || origin.Host == "" {
		return false
	}
	if strings.EqualFold(origin.Host, r.Host) {
		return true
	}
	for _, host := range r.Header.Values("X-Forwarded-Host") {
		if strings.EqualFold(origin.Host, strings.TrimSpace(host)) {
			return true
		}
	}
	return false
}

// stripAdminCredentials removes from a request sent to a connector-remote
// what identifies or authenticates the admin: the API token (cookie or
// header) and the identity added by the aaa layer.
func stripAdminCredentials(req *http.Request) {
	for _, h := range []string{
		"Cookie",
		"Authorization",
		"X-PacketFence-Admin-Roles",
		"X-PacketFence-Username",
		"X-PacketFence-Tenant-Id",
		"X-Forwarded-For",
		"X-Real-Ip",
		"Origin",
		"Referer",
	} {
		req.Header.Del(h)
	}
}

// remoteSecurityHeaders makes sure a response coming from a connector-remote
// can't be rendered in the admin origin, nor set cookies on it.
func remoteSecurityHeaders(header http.Header, statusCode int) {
	header.Del("Set-Cookie")
	header.Set("X-Content-Type-Options", "nosniff")
	header.Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; sandbox")
	if statusCode != http.StatusSwitchingProtocols {
		header.Set("Content-Type", "text/plain; charset=utf-8")
	}
}

// newRemoteWebsocketProxy returns a reverse proxy to a connector-remote's
// local API for a websocket stream at escapedPath (already path-escaped): the
// admin's credentials are stripped from the request, and the response of the
// remote can't set cookies nor be rendered as a document in the admin origin.
func newRemoteWebsocketProxy(target *url.URL, escapedPath string, extraHeaders http.Header) *httputil.ReverseProxy {
	path, err := url.PathUnescape(escapedPath)
	if err != nil {
		path = escapedPath
	}
	proxy := httputil.NewSingleHostReverseProxy(target)
	director := proxy.Director
	proxy.Director = func(req *http.Request) {
		director(req)
		req.Host = target.Host
		req.URL.Path = path
		req.URL.RawPath = escapedPath
		stripAdminCredentials(req)
		// nil, not deleted: ReverseProxy would add the admin's address
		req.Header["X-Forwarded-For"] = nil
		for name, values := range extraHeaders {
			req.Header[name] = values
		}
	}
	proxy.ModifyResponse = func(res *http.Response) error {
		remoteSecurityHeaders(res.Header, res.StatusCode)
		return nil
	}
	return proxy
}
