// Copyright 2017 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Caching is purposefully ignored. Pipelining is expected to work, but doesn't have to. Might be (ab)used to get
// into internal networks.
package forwardproxy

import (
	"crypto/subtle"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
)

type ForwardProxy struct {
	httpTransport      http.Transport
	Next               httpserver.Handler
	authRequired       bool
	authCredentials    [][]byte // slice with base64-encoded credentials
	hideIP             bool
	whitelistedPorts   []int
	probeResistDomain  string
	pacFilePath        string
	probeResistEnabled bool
	dialTimeout        time.Duration // for initial tcp connection
	hostname           string        // do not intercept requests to the hostname (except for hidden link)
	port               string        // port on which chain with forwardproxy is listening on
}

var bufferPool sync.Pool

// TODO?: getStatusCode(err) that casts to http.Error, net Error, etc. and returns correct http status code

func (fp *ForwardProxy) connectPortIsAllowed(port string) bool {
	portInt, err := strconv.Atoi(port)
	if err != nil {
		return false
	}
	if portInt <= 0 || portInt > 65535 {
		return false
	}
	if len(fp.whitelistedPorts) == 0 {
		return true
	}
	isAllowed := false
	for _, p := range fp.whitelistedPorts {
		if p == portInt {
			isAllowed = true
			break
		}
	}
	return isAllowed
}

// Copies data r1->w1 and r2->w2, flushes as needed, and returns when both streams are done.
func dualStream(w1 io.Writer, r1 io.Reader, w2 io.Writer, r2 io.Reader) error {
	errChan := make(chan error)

	stream := func(w io.Writer, r io.Reader) {
		buf := bufferPool.Get().([]byte)
		buf = buf[0:cap(buf)]
		_, _err := flushingIoCopy(w, r, buf)
		errChan <- _err
	}

	go stream(w1, r1)
	go stream(w2, r2)
	err1 := <-errChan
	err2 := <-errChan
	if err1 != nil {
		return err1
	}
	return err2
}

// Hijacks the connection from ResponseWriter, writes the response and proxies data between targetConn
// and hijacked connection.
func serveHijack(w http.ResponseWriter, targetConn net.Conn) (int, error) {
	hijacker, ok := w.(http.Hijacker)
	if !ok {
		return http.StatusInternalServerError, errors.New("ResponseWriter does not implement Hijacker")
	}
	clientConn, bufReader, err := hijacker.Hijack()
	if err != nil {
		return http.StatusInternalServerError, errors.New("failed to hijack: " + err.Error())
	}
	defer clientConn.Close()
	// bufReader may contain unprocessed buffered data from the client.
	if bufReader != nil {
		// snippet borrowed from `proxy` plugin
		if n := bufReader.Reader.Buffered(); n > 0 {
			rbuf, err := bufReader.Reader.Peek(n)
			if err != nil {
				return http.StatusBadGateway, err
			}
			targetConn.Write(rbuf)
		}
	}
	// Since we hijacked the connection, we lost the ability to write and flush headers via w.
	// Let's handcraft the response and send it manually.
	res := &http.Response{StatusCode: http.StatusOK,
		Proto:      "HTTP/1.1",
		ProtoMajor: 1,
		ProtoMinor: 1,
		Header:     make(http.Header),
	}
	res.Header.Set("Server", "Caddy")

	err = res.Write(clientConn)
	if err != nil {
		return http.StatusInternalServerError, errors.New("failed to send response to client: " + err.Error())
	}

	return 0, dualStream(targetConn, clientConn, clientConn, targetConn)
}

// Returns nil error on successful credentials check.
func (fp *ForwardProxy) checkCredentials(r *http.Request) error {
	pa := strings.Split(r.Header.Get("Proxy-Authorization"), " ")
	if len(pa) != 2 {
		return errors.New("Proxy-Authorization is required! Expected format: <type> <credentials>")
	}
	if strings.ToLower(pa[0]) != "basic" {
		return errors.New("Auth type is not supported")
	}
	for _, creds := range fp.authCredentials {
		if subtle.ConstantTimeCompare(creds, []byte(pa[1])) == 1 {
			// Please do not consider this to be timing-attack-safe code. Simple equality is almost
			// mindlessly substituted with constant time algo and there ARE known issues with this code,
			// e.g. size of smallest credentials is guessable. TODO: protect from all the attacks! Hash?
			return nil
		}
	}
	return errors.New("Invalid credentials")
}

// returns true if `s` is `domain` or subdomain of `domain`. Inputs are expected to be sanitized.
func isSubdomain(s, domain string) bool {
	if s == domain {
		return true
	}
	if strings.HasSuffix(s, "."+domain) {
		return true
	}
	return false
}

// borrowed from `proxy` plugin
func stripPort(address string) string {
	// Keep in mind that the address might be a IPv6 address
	// and thus contain a colon, but not have a port.
	portIdx := strings.LastIndex(address, ":")
	ipv6Idx := strings.LastIndex(address, "]")
	if portIdx > ipv6Idx {
		address = address[:portIdx]
	}
	return address
}

func serveHiddenPage(w http.ResponseWriter, authErr error) (int, error) {
	const hiddenPage = `<html>
<head>
  <title>Hidden Proxy Page</title>
</head>
<body>
<h1>Hidden Proxy Page!</h1>
%s<br/>
</body>
</html>`
	const AuthFail = "Please authenticate yourself to the proxy."
	const AuthOk = "Congratulations, you are successfully authenticated to the proxy! Go browse all the things!"

	if authErr != nil {
		w.Header().Set("Proxy-Authenticate", "Basic")
		w.WriteHeader(http.StatusProxyAuthRequired)
		w.Write([]byte(fmt.Sprintf(hiddenPage, AuthFail)))
		return 0, authErr
	}
	w.Write([]byte(fmt.Sprintf(hiddenPage, AuthOk)))
	return 0, nil
}

func (fp *ForwardProxy) shouldServePacFile(r *http.Request) bool {
	if len(fp.pacFilePath) > 0 && r.URL.Path == fp.pacFilePath {
		return true
	}
	return false
}

const pacFile = `
function FindProxyForURL(url, host) {
	if (host === "127.0.0.1" || host === "::1" || host === "localhost")
		return "DIRECT";
	return "HTTPS %s:%s";
}
`

func (fp *ForwardProxy) servePacFile(w http.ResponseWriter) (int, error) {
	fmt.Fprintf(w, pacFile, fp.hostname, fp.port)
	return 0, nil
}

func (fp *ForwardProxy) ServeHTTP(w http.ResponseWriter, r *http.Request) (int, error) {
	var authErr error
	if fp.authRequired {
		authErr = fp.checkCredentials(r)
	}
	if fp.probeResistEnabled && len(fp.probeResistDomain) > 0 && stripPort(r.Host) == fp.probeResistDomain {
		return serveHiddenPage(w, authErr)
	}
	if isSubdomain(stripPort(r.Host), fp.hostname) && (r.Method != http.MethodConnect || authErr != nil) {
		// Always pass non-CONNECT requests to hostname
		// Pass CONNECT requests only if probe resistance is enabled and not authenticated
		if fp.shouldServePacFile(r) {
			return fp.servePacFile(w)
		}
		return fp.Next.ServeHTTP(w, r)
	}
	if authErr != nil {
		if fp.probeResistEnabled {
			// probe resistance is requested and requested URI does not match secret domain
			//httpserver.WriteSiteNotFound(w, r)
			return 0, authErr // current Caddy behavior without forwardproxy
		} else {
			w.Header().Set("Proxy-Authenticate", "Basic")
			return http.StatusProxyAuthRequired, authErr
		}
	}

	if r.ProtoMajor != 1 && r.ProtoMajor != 2 {
		return http.StatusHTTPVersionNotSupported, errors.New("Unsupported HTTP major version: " + strconv.Itoa(r.ProtoMajor))
	}

	if r.Method == http.MethodConnect {
		if r.ProtoMajor == 2 {
			if len(r.URL.Scheme) > 0 || len(r.URL.Path) > 0 {
				return http.StatusBadRequest, errors.New("CONNECT request has :scheme or/and :path pseudo-header fields")
			}
		}

		if !fp.connectPortIsAllowed(r.URL.Port()) {
			return http.StatusForbidden, errors.New("CONNECT port not allowed for " + r.URL.String())
		}

		targetConn, err := net.DialTimeout("tcp", r.URL.Hostname()+":"+r.URL.Port(), fp.dialTimeout)
		if err != nil {
			return http.StatusBadGateway, errors.New(fmt.Sprintf("Dial %s failed: %v", r.URL.String(), err))
		}
		defer targetConn.Close()

		switch r.ProtoMajor {
		case 1: // http1: hijack the whole flow
			return serveHijack(w, targetConn)
		case 2: // http2: keep reading from "request" and writing into same response
			defer r.Body.Close()
			wFlusher, ok := w.(http.Flusher)
			if !ok {
				return http.StatusInternalServerError, errors.New("ResponseWriter doesn't implement Flusher()")
			}
			w.WriteHeader(http.StatusOK)
			wFlusher.Flush()
			return 0, dualStream(targetConn, r.Body, w, targetConn)
		default:
			panic("There was a check for http version, yet it's incorrect")
		}
	} else {
		outReq, err := fp.generateForwardRequest(r)
		if err != nil {
			return http.StatusBadRequest, err
		}
		response, err := fp.httpTransport.RoundTrip(outReq)
		if err != nil {
			if response != nil {
				if response.StatusCode != 0 {
					return response.StatusCode, errors.New("failed to do RoundTrip(): " + err.Error())
				}
			}
			return http.StatusBadGateway, errors.New("failed to do RoundTrip(): " + err.Error())
		}
		return 0, forwardResponse(w, response)
	}
}

// Removes hop-by-hop headers, and writes response into ResponseWriter.
func forwardResponse(w http.ResponseWriter, response *http.Response) error {
	w.Header().Del("Server") // remove Server: Caddy, append via instead
	w.Header().Add("Via", strconv.Itoa(response.ProtoMajor)+"."+strconv.Itoa(response.ProtoMinor)+" caddy")

	for header, values := range response.Header {
		for _, val := range values {
			w.Header().Add(header, val)
		}
	}
	removeHopByHop(w.Header())
	w.WriteHeader(response.StatusCode)
	buf := bufferPool.Get().([]byte)
	buf = buf[0:cap(buf)]
	_, err := io.CopyBuffer(w, response.Body, buf)
	response.Body.Close()
	return err
}

// Based on http Request from client, generates new request to be forwarded to target server.
// Some fields are shallow-copied, thus genOutReq will mutate original request.
// If error is not nil - http.StatusBadRequest is to be sent to client.
func (fp *ForwardProxy) generateForwardRequest(inReq *http.Request) (*http.Request, error) {
	// Scheme has to be appended to avoid `unsupported protocol scheme ""` error.
	// `http://` is used, since this initial request itself is always HTTP, regardless of what client and server
	// may speak afterwards.
	if len(inReq.RequestURI) == 0 {
		return nil, errors.New("malformed request: empty URI")
	}
	strUrl := inReq.RequestURI
	if strUrl[0] == '/' {
		strUrl = inReq.Host + strUrl
	}
	if !strings.Contains(strUrl, "://") {
		strUrl = "http://" + strUrl
	}
	outReq, err := http.NewRequest(inReq.Method, strUrl, inReq.Body)
	if err != nil {
		return outReq, errors.New("failed to create NewRequest: " + err.Error())
	}
	for key, values := range inReq.Header {
		for _, value := range values {
			outReq.Header.Add(key, value)
		}
	}
	removeHopByHop(outReq.Header)

	if !fp.hideIP {
		outReq.Header.Add("Forwarded", "for=\""+inReq.RemoteAddr+"\"")
	}

	// https://tools.ietf.org/html/rfc7230#section-5.7.1
	outReq.Header.Add("Via", strconv.Itoa(inReq.ProtoMajor)+"."+strconv.Itoa(inReq.ProtoMinor)+" caddy")
	return outReq, nil
}

var hopByHopHeaders = []string{
	"Keep-Alive",
	"Proxy-Authenticate",
	"Proxy-Authorization",
	"Upgrade",
	"Connection",
	"Proxy-Connection",
	"Te",
	"Trailer",
	"Transfer-Encoding",
}

func removeHopByHop(header http.Header) {
	connectionHeaders := header.Get("Connection")
	for _, h := range strings.Split(connectionHeaders, ",") {
		header.Del(strings.TrimSpace(h))
	}
	for _, h := range hopByHopHeaders {
		header.Del(h)
	}
}

// flushingIoCopy is analogous to buffering io.Copy(), but also attempts to flush on each iteration.
// If dst does not implement http.Flusher(e.g. net.TCPConn), it will do a simple io.CopyBuffer().
// Reasoning: http2ResponseWriter will not flush on its own, so we have to do it manually.
func flushingIoCopy(dst io.Writer, src io.Reader, buf []byte) (written int64, err error) {
	flusher, ok := dst.(http.Flusher)
	if !ok {
		return io.CopyBuffer(dst, src, buf)
	}
	for {
		nr, er := src.Read(buf)
		if nr > 0 {
			nw, ew := dst.Write(buf[0:nr])
			flusher.Flush()
			if nw > 0 {
				written += int64(nw)
			}
			if ew != nil {
				err = ew
				break
			}
			if nr != nw {
				err = io.ErrShortWrite
				break
			}
		}
		if er != nil {
			if er != io.EOF {
				err = er
			}
			break
		}
	}
	return
}
