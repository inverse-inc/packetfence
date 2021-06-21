package main

import (
	"context"
	"database/sql"
	"net"
	"time"

	cache "github.com/fdurand/go-cache"
	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/go-radius"
	"github.com/inverse-inc/go-radius/rfc2866"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/mac"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	"github.com/inverse-inc/packetfence/go/tryableonce"
	statsd "gopkg.in/alexcesaro/statsd.v2"
)

const DefaultTimeDuration = 5 * time.Minute

type radiusRequest struct {
	w          radius.ResponseWriter
	r          *radius.Request
	switchInfo *SwitchInfo
	status     rfc2866.AcctStatusType
	mac        mac.Mac
	done       chan struct{}
}

type PfAcct struct {
	RadiusStatements
	TimeDuration       time.Duration
	Db                 *sql.DB
	AllowedNetworks    []net.IPNet
	NetFlowPort        string
	NetFlowAddress     string
	Management         pfconfigdriver.ManagementNetwork
	AAAClient          *jsonrpc2.Client
	LoggerCtx          context.Context
	Dispatcher         *Dispatcher
	SwitchInfoCache    *cache.Cache
	StatsdAddress      string
	StatsdOption       statsd.Option
	StatsdClient       *statsd.Client
	radiusRequests     []chan<- radiusRequest
	localSecret        string
	StatsdOnce         tryableonce.TryableOnce
	isProxied          bool
	radiusdAcctEnabled bool
	AllNetworks        bool
}

func NewPfAcct() *PfAcct {
	var ctx = context.Background()
	ctx = log.LoggerNewContext(ctx)

	Database, err := db.DbFromConfig(ctx)
	for err != nil {
		time.Sleep(time.Duration(5) * time.Second)
		Database, err = db.DbFromConfig(ctx)
	}

	err = Database.Ping()
	for err != nil {
		time.Sleep(time.Duration(5) * time.Second)
		err = Database.Ping()
	}

	pfAcct := &PfAcct{Db: Database, TimeDuration: DefaultTimeDuration}
	pfAcct.SwitchInfoCache = cache.New(5*time.Minute, 10*time.Minute)
	pfAcct.LoggerCtx = ctx
	pfAcct.RadiusStatements.Setup(pfAcct.Db)

	pfAcct.SetupConfig(ctx)
	pfAcct.radiusRequests = makeRadiusRequests(pfAcct, 5, 10)
	pfAcct.AAAClient = jsonrpc2.NewAAAClientFromConfig(ctx)
	//pfAcct.Dispatcher = NewDispatcher(16, 128)
	pfAcct.runPing()
	return pfAcct
}

func makeRadiusRequests(h *PfAcct, requestFanOut, backlog int) []chan<- radiusRequest {
	requests := make([]chan<- radiusRequest, requestFanOut)
	for i := 0; i < requestFanOut; i++ {
		c := make(chan radiusRequest, backlog)
		requests[i] = c
		go func(c <-chan radiusRequest) {
			for rr := range c {
				h.handleAccountingRequest(rr)
			}
		}(c)
	}

	return requests
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

	keyPfConfServices := pfconfigdriver.PfConfServices{}
	keyPfConfServices.PfconfigNS = "config::Pf"
	keyPfConfServices.PfconfigHostnameOverlay = "yes"
	pfconfigdriver.FetchDecodeSocket(ctx, &keyPfConfServices)
	if keyPfConfServices.NetFlowAddress != "" {
		pfAcct.NetFlowAddress = keyPfConfServices.NetFlowAddress
	} else {
		pfAcct.NetFlowAddress = defaultNetFlowAddr
	}

	pfAcct.StatsdOption = statsd.Address("localhost:" + keyConfAdvanced.StatsdListenPort)
	pfAcct.NetFlowPort = ports.PFAcctNetflow
	pfconfigdriver.FetchDecodeSocket(ctx, &pfAcct.Management)

	var servicesConf pfconfigdriver.PfConfServices
	pfconfigdriver.FetchDecodeSocket(ctx, &servicesConf)
	pfAcct.radiusdAcctEnabled = sharedutils.IsEnabled(servicesConf.RadiusdAcct)

	localSecret := pfconfigdriver.LocalSecret{}
	pfconfigdriver.FetchDecodeSocket(ctx, &localSecret)
	pfAcct.localSecret = localSecret.Element

	pfAcct.isProxied = isProxied(pfAcct)
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

func (pfAcct *PfAcct) DbPing() error {
	if pfAcct.Db == nil {
		return nil
	}

	return pfAcct.Db.Ping()
}

func (pfAcct *PfAcct) runPing() {
	go func(pfAcct *PfAcct) {
		for {
			time.Sleep(60 * time.Second)
			if err := pfAcct.DbPing(); err != nil {
				logError(pfAcct.LoggerCtx, "Unable to ping DB: "+err.Error())
			} else {
				logDebug(pfAcct.LoggerCtx, "Pinged DB")
			}
		}
	}(pfAcct)
}

func isProxied(pfAcct *PfAcct) bool {
	return pfconfigdriver.GetClusterSummary(context.Background()).ClusterEnabled == 1 || pfAcct.radiusdAcctEnabled
}

// Send function to add pf prefix
func (t *Timing) Send(name string) {
	if t == nil {
		return
	}

	t.timing.Send(name)
}
