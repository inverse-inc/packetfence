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

package forwardproxy

import (
	"encoding/base64"
	"errors"
	"log"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/inverse-inc/packetfence/go/caddy/caddy"
	"github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"
)

func setup(c *caddy.Controller) error {
	//httpserver.GetConfig(c).FallbackSite = true
	fp := &ForwardProxy{dialTimeout: time.Second * 20,
		hostname: httpserver.GetConfig(c).Host(), port: httpserver.GetConfig(c).Port(),
		httpTransport: http.Transport{
			Proxy:                 http.ProxyFromEnvironment,
			MaxIdleConns:          100,
			IdleConnTimeout:       90 * time.Second,
			TLSHandshakeTimeout:   10 * time.Second,
			ExpectContinueTimeout: 1 * time.Second,
		}}
	fp.httpTransport.DialTLS = func(network, addr string) (net.Conn, error) {
		return nil, &http.ProtocolError{ErrorString: "Proxy does not fetch TLS resources, use CONNECT instead"}
	}

	c.Next() // skip the directive name

	args := c.RemainingArgs()
	if len(args) > 0 {
		return c.ArgErr()
	}

	for c.NextBlock() {
		subdirective := c.Val()
		args := c.RemainingArgs()
		switch subdirective {
		case "basicauth":
			if len(args) != 2 {
				return c.ArgErr()
			}
			if len(args[0]) == 0 {
				return errors.New("Parse error: empty usernames are not allowed")
			}
			// TODO: Evaluate policy of allowing empty passwords.
			if strings.Contains(args[0], ":") {
				return errors.New("Parse error: character ':' in usernames is not allowed")
			}
			if fp.authCredentials == nil {
				fp.authCredentials = [][]byte{}
			}
			// base64-encode credentials
			buf := make([]byte, base64.StdEncoding.EncodedLen(len(args[0])+1+len(args[1])))
			base64.StdEncoding.Encode(buf, []byte(args[0]+":"+args[1]))
			fp.authCredentials = append(fp.authCredentials, buf)
			fp.authRequired = true
		case "ports":
			if len(args) == 0 {
				return c.ArgErr()
			}
			if len(fp.whitelistedPorts) != 0 {
				return errors.New("Parse error: ports subdirective specified twice")
			}
			fp.whitelistedPorts = make([]int, len(args))
			for i, p := range args {
				intPort, err := strconv.Atoi(p)
				if intPort <= 0 || intPort > 65535 || err != nil {
					return errors.New("Parse error: ports are expected to be space-separated" +
						" and in 0-65535 range. Got: " + p)
				}
				fp.whitelistedPorts[i] = intPort
			}
		case "hide_ip":
			if len(args) != 0 {
				return c.ArgErr()
			}
			fp.hideIP = true
		case "probe_resistance":
			if len(args) > 1 {
				return c.ArgErr()
			}
			fp.probeResistEnabled = true
			if len(args) == 1 {
				fp.probeResistDomain = args[0]
			}
		case "serve_pac":
			if len(args) > 1 {
				return c.ArgErr()
			}
			if len(fp.pacFilePath) != 0 {
				return errors.New("Parse error: serve_pac subdirective specified twice")
			}
			if len(args) == 1 {
				fp.pacFilePath = args[0]
				if !strings.HasPrefix(fp.pacFilePath, "/") {
					fp.pacFilePath = "/" + fp.pacFilePath
				}
			} else {
				fp.pacFilePath = "/proxy.pac"
			}
			log.Printf("Proxy Auto-Config will be served at %s%s\n", fp.hostname, fp.pacFilePath)
		case "response_timeout":
			if len(args) != 1 {
				return c.ArgErr()
			}
			timeout, err := strconv.Atoi(args[0])
			if err != nil {
				return c.ArgErr()
			}
			if timeout < 0 {
				return errors.New("Parse error: response_timeout cannot be negative.")
			}
			fp.httpTransport.ResponseHeaderTimeout = time.Second * time.Duration(timeout)
		case "dial_timeout":
			if len(args) != 1 {
				return c.ArgErr()
			}
			timeout, err := strconv.Atoi(args[0])
			if err != nil {
				return c.ArgErr()
			}
			if timeout < 0 {
				return errors.New("Parse error: dial_timeout cannot be negative.")
			}
			fp.dialTimeout = time.Second * time.Duration(timeout)
		default:
			return c.ArgErr()
		}
	}

	if fp.probeResistEnabled {
		if !fp.authRequired {
			return errors.New("Parse error: probing resistance requires authentication")
		}
		if len(fp.probeResistDomain) > 0 {
			log.Printf("Secret domain used to connect to proxy: %s\n", fp.probeResistDomain)
		}
	}

	fp.httpTransport.DialContext = (&net.Dialer{
		Timeout:   fp.dialTimeout,
		KeepAlive: 30 * time.Second,
		DualStack: true,
	}).DialContext

	httpserver.GetConfig(c).AddMiddleware(func(next httpserver.Handler) httpserver.Handler {
		fp.Next = next
		return fp
	})

	makeBuffer := func() interface{} { return make([]byte, 0, 32*1024) }
	bufferPool = sync.Pool{New: makeBuffer}
	return nil
}

func init() {
	caddy.RegisterPlugin("forwardproxy", caddy.Plugin{
		ServerType: "http",
		Action:     setup,
	})
}
