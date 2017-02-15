package caddyhttp

import (
	// plug in the server
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/httpserver"

	// plug in the standard directives
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/basicauth"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/bind"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/browse"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/errors"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/expvar"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/extensions"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/fastcgi"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/gzip"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/header"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/internalsrv"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/log"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/markdown"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/maxrequestbody"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/mime"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/pprof"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/proxy"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/redirect"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/rewrite"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/root"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/status"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/templates"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/timeouts"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/caddyhttp/websocket"
	_ "github.com/inverse-inc/packetfence/go/caddy/caddy/startupshutdown"
)
