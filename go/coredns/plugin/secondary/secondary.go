// Package secondary implements a secondary plugin.
package secondary

import "github.com/inverse-inc/packetfence/go/coredns/plugin/file"

// Secondary implements a secondary plugin that allows CoreDNS to retrieve (via AXFR)
// zone information from a primary server.
type Secondary struct {
	file.File
}
