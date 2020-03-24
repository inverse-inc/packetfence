package main

import (
	"context"
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"net"
	"time"
)

const DefaultTimeDuration = 5 * time.Minute

type PfAcct struct {
	RadiusStatements
	Db              *sql.DB
	TimeDuration    time.Duration
	AllowedNetworks []net.IPNet
	NetFlowPort     string
	AllNetworks     bool
	Management      pfconfigdriver.ManagementNetwork
	AAAClient       *jsonrpc2.Client
	LoggerCtx       context.Context
	Dispatcher      *Dispatcher
}

func NewPfAcct() *PfAcct {
	var ctx = context.Background()
	ctx = log.LoggerNewContext(ctx)
	db, err := db.DbFromConfig(ctx)
	if err != nil {
		return nil
	}

	pfAcct := &PfAcct{Db: db, TimeDuration: DefaultTimeDuration}
	pfAcct.LoggerCtx = ctx
	pfAcct.RadiusStatements.Setup(pfAcct.Db)
	pfAcct.SetupConfig(ctx)
	pfAcct.AAAClient = jsonrpc2.NewAAAClientFromConfig(ctx)
	//pfAcct.Dispatcher = NewDispatcher(16, 128)
	return pfAcct
}

func (pfAcct *PfAcct) SetupConfig(ctx context.Context) {
	var keyConfNet pfconfigdriver.PfconfigKeys
	keyConfNet.PfconfigNS = "config::Network"
	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfNet)
	for _, key := range keyConfNet.Keys {
		var ConfNet pfconfigdriver.RessourseNetworkConf
		ConfNet.PfconfigHashNS = key
		pfconfigdriver.FetchDecodeSocket(ctx, &ConfNet)
		if ConfNet.NetflowAccountingEnabled == "disabled" {
			continue
		}
		var network net.IPNet
		network.IP = net.ParseIP(key)
		network.Mask = net.IPMask(net.ParseIP(ConfNet.Netmask))
		pfAcct.AllowedNetworks = append(pfAcct.AllowedNetworks, network)
	}

	keyConfAdvanced := pfconfigdriver.PfConfAdvanced{}
	keyConfAdvanced.PfconfigNS = "config::Pf"
	keyConfAdvanced.PfconfigHostnameOverlay = "yes"
	pfconfigdriver.FetchDecodeSocket(ctx, &keyConfAdvanced)
	pfAcct.AllNetworks = keyConfAdvanced.NetFlowOnAllNetworks == "enabled"
	var ports pfconfigdriver.PfConfPorts
	pfconfigdriver.FetchDecodeSocket(ctx, &ports)
    pfAcct.TimeDuration = time.Duration(keyConfAdvanced.AccountingTimebucketSize) * time.Second
    if pfAcct.TimeDuration == 0 {
        pfAcct.TimeDuration = DefaultTimeDuration
    }
	pfAcct.NetFlowPort = ports.PFAcctNetflow
	pfconfigdriver.FetchDecodeSocket(ctx, &pfAcct.Management)
}
