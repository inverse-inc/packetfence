// Copyright 2015 Light Code Labs, LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package caddyhttp

import (
	// plug in the server
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"

	// plug in the standard directives
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/basicauth"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/bind"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/errors"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/expvar"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/extensions"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/gzip"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/header"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/index"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/internalsrv"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/limits"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/log"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/mime"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/pprof"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/proxy"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/redirect"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/requestid"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/rewrite"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/root"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/status"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/templates"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/timeouts"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/websocket"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/onevent"
)
