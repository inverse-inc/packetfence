// Package bind allows binding to a specific interface instead of bind to all of them.
package bind

import "github.com/inverse-inc/packetfence/go/caddy/caddy"

func init() {
	caddy.RegisterPlugin("bind", caddy.Plugin{
		ServerType: "dns",
		Action:     setupBind,
	})
}
