package pfdns

import (
	"context"
	"regexp"

	"github.com/inverse-inc/packetfence/go/log"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func (pf *pfdns) Refresh(ctx context.Context) {
	// If some of the passthroughs were changed, we should reload
	if !pfconfigdriver.IsValid(ctx, &pfconfigdriver.Config.Passthroughs.Registration) || !pfconfigdriver.IsValid(ctx, &pfconfigdriver.Config.Passthroughs.Isolation) {
		log.LoggerWContext(ctx).Info("Reloading passthroughs and flushing cache")
		pf.PassthroughsInit()
		pf.PassthroughsIsolationInit()

		pf.DNSFilter.Flush()
		pf.IpsetCache.Flush()
	}
	if !pfconfigdriver.IsValid(ctx, &pfconfigdriver.Config.Dns.Configuration) {
		pf.DNSRecord()
	}
}

func (pf *pfdns) PassthroughsInit() error {
	var ctx = context.Background()

	pfconfigdriver.FetchDecodeSocket(ctx, &pfconfigdriver.Config.Passthroughs.Registration)

	pf.FqdnPort = make(map[*regexp.Regexp][]string)

	for k, v := range pfconfigdriver.Config.Passthroughs.Registration.Wildcard {
		rgx, _ := regexp.Compile(".*" + k)
		pf.FqdnPort[rgx] = v
	}

	for k, v := range pfconfigdriver.Config.Passthroughs.Registration.Normal {
		rgx, _ := regexp.Compile("^" + k + ".$")
		pf.FqdnPort[rgx] = v
	}

	return nil
}

func (pf *pfdns) PassthroughsIsolationInit() error {
	var ctx = context.Background()

	pfconfigdriver.FetchDecodeSocket(ctx, &pfconfigdriver.Config.Passthroughs.Isolation)

	pf.FqdnIsolationPort = make(map[*regexp.Regexp][]string)

	for k, v := range pfconfigdriver.Config.Passthroughs.Isolation.Wildcard {
		rgx, _ := regexp.Compile(".*" + k)
		pf.FqdnIsolationPort[rgx] = v
	}

	for k, v := range pfconfigdriver.Config.Passthroughs.Isolation.Normal {
		rgx, _ := regexp.Compile("^" + k + ".$")
		pf.FqdnIsolationPort[rgx] = v
	}
	return nil
}

func (pf *pfdns) DNSRecord() error {
	var ctx = context.Background()

	pfconfigdriver.FetchDecodeSocket(ctx, &pfconfigdriver.Config.Dns.Configuration)
	if pfconfigdriver.Config.Dns.Configuration.RecordDNS == "enabled" {
		pf.recordDNS = true
	} else {
		pf.recordDNS = false
	}
	return nil
}
