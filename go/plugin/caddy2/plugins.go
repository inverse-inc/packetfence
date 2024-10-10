package caddy2

import (
	_ "github.com/caddyserver/forwardproxy"
	_ "github.com/caddyserver/transform-encoder"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/api"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/api-aaa"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/configstore"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/cors"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/httpdispatcher"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/httpdportalpreview"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/job-status"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/log-tailer"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/logger"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/pfipset"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/pfldapexplorer"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/pfsso"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/requestlimit"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/statsd"
)
