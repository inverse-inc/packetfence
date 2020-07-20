package main

import (
	"context"
	"database/sql"
	"net"
	"time"

	cache "github.com/fdurand/go-cache"
	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/tryableonce"
	statsd "gopkg.in/alexcesaro/statsd.v2"
)

const DefaultTimeDuration = 5 * time.Minute

var successDBConnect = false

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
	SwitchInfoCache *cache.Cache
	StatsdOnce      tryableonce.TryableOnce
	StatsdAddress   string
	StatsdOption    statsd.Option
	StatsdClient    *statsd.Client
}

func NewPfAcct() *PfAcct {
	var ctx = context.Background()
	ctx = log.LoggerNewContext(ctx)

	Database, err := db.DbFromConfig(ctx)
	for err != nil {
		if err != nil {
			time.Sleep(time.Duration(5) * time.Second)
		}

		Database, err = db.DbFromConfig(ctx)
	}

	for !successDBConnect {
		err = Database.Ping()
		if err != nil {
			time.Sleep(time.Duration(5) * time.Second)
		} else {
			successDBConnect = true
		}
	}

	pfAcct := &PfAcct{Db: Database, TimeDuration: DefaultTimeDuration}
	pfAcct.SwitchInfoCache = cache.New(5*time.Minute, 10*time.Minute)
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

	pfAcct.StatsdOption = statsd.Address("localhost:" + keyConfAdvanced.StatsdListenPort)
	pfAcct.NetFlowPort = ports.PFAcctNetflow
	pfconfigdriver.FetchDecodeSocket(ctx, &pfAcct.Management)
}

// Timing struct
type Timing struct {
	timing statsd.Timing
}

// NewTiming struct
func (pfAcct *PfAcct) NewTiming() *Timing {
	err := pfAcct.StatsdOnce.Do(
		func() error {
			var err error
			pfAcct.StatsdClient, err = statsd.New(pfAcct.StatsdOption)
			return err
		},
	)

	if err != nil || pfAcct.StatsdClient == nil {
		return nil
	}

	return &Timing{timing: pfAcct.StatsdClient.NewTiming()}
}

// Send function to add pf prefix
func (t *Timing) Send(name string) {
	if t == nil {
		return
	}

	t.timing.Send(name)
}
