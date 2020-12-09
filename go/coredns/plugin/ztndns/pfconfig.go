package ztndns

import (
	"context"
	"net"
	"regexp"

	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/inverse-inc/packetfence/go/timedlock"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// GlobalTransactionLock global var
var GlobalTransactionLock *timedlock.RWLock

var startingIP = sharedutils.IP2Int(net.ParseIP("100.64.0.0"))

func (ztn *ztndns) Refresh(ctx context.Context) {
	// If some of the passthroughs were changed, we should reload
	if !pfconfigdriver.IsValid(ctx, &pfconfigdriver.Config.Passthroughs.Registration) || !pfconfigdriver.IsValid(ctx, &pfconfigdriver.Config.Passthroughs.Isolation) {
		log.LoggerWContext(ctx).Info("Reloading passthroughs and flushing cache")
		ztn.HostIPMAP(ctx)

	}
	if !pfconfigdriver.IsValid(ctx, &pfconfigdriver.Config.Dns.Configuration) {
		ztn.DNSRecord(ctx)
	}
}

func (ztn *ztndns) HostIPMAP(ctx context.Context) error {

	pfconfigdriver.FetchDecodeSocket(ctx, &pfconfigdriver.Config.Passthroughs.Registration)

	ztn.HostIP = make(map[*regexp.Regexp]net.IP)

	rows, err := ztn.Db.Query("select node.computername ,id from remote_clients join node on remote_clients.mac=node.mac")
	if err != nil {
		// Log here
		return err
	}

	defer rows.Close()
	var (
		hostname string
		id       uint
	)
	for rows.Next() {
		err := rows.Scan(&hostname, &id)
		if err != nil {
			return err

		}
		rgx, _ := regexp.Compile(hostname + ".*")
		ztn.HostIP[rgx] = sharedutils.Int2IP(startingIP + uint32(id))
	}

	return nil
}

func (ztn *ztndns) DNSRecord(ctx context.Context) error {

	pfconfigdriver.FetchDecodeSocket(ctx, &pfconfigdriver.Config.Dns.Configuration)
	if pfconfigdriver.Config.Dns.Configuration.RecordDNS == "enabled" {
		ztn.recordDNS = true
	} else {
		ztn.recordDNS = false
	}
	return nil
}
