package caddy2

import (
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/configstore"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/job-status"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/log-tailer"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/logger"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/pfconfig"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/pfipset"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/pfldapexplorer"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/pfsso"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/requestlimit"
	_ "github.com/inverse-inc/packetfence/go/plugin/caddy2/statsd"
)
