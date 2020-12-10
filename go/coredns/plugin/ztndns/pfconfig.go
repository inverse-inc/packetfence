package ztndns

import (
	"context"
	"regexp"

	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/timedlock"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

// GlobalTransactionLock global var
var GlobalTransactionLock *timedlock.RWLock

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

	ztn.HostIP = make(map[int]*HostIPMap)

	rows, err := ztn.Db.Query("SELECT n.computername, m.id FROM remote_clients m LEFT JOIN remote_clients b ON m.mac = b.mac AND m.updated_at < b.updated_at LEFT JOIN node n ON n.mac = m.mac WHERE b.updated_at IS NULL AND n.computername is not NULL order by length(n.computername) DESC;")
	if err != nil {
		// Log here
		return err
	}

	defer rows.Close()
	var (
		hostname string
		id       uint
	)
	i := 0
	for rows.Next() {
		err := rows.Scan(&hostname, &id)
		if err != nil {
			return err

		}
		rgx, _ := regexp.Compile(hostname + ".*")
		HostIpmap := &HostIPMap{}
		HostIpmap.ComputerName = rgx
		HostIpmap.Ip = RemoteClient{ID: ID}.IPAddress()
		ztn.HostIP[i] = HostIpmap
		i++
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
