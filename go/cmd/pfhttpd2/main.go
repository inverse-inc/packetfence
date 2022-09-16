package main

import (
	caddycmd "github.com/caddyserver/caddy/v2/cmd"

	// plug in Caddy modules here
	_ "github.com/caddyserver/caddy/v2/modules/standard"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/api"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/api-aaa"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/cors"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/httpdispatcher"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/httpdportalpreview"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/job-status"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/logger"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/pfconfig"
)

func main() {
	caddycmd.Main()
}
