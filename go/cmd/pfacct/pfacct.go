package main

import (
	"cmp"
	"context"
	"database/sql"
	"fmt"
	"net"
	"runtime"
	"strconv"
	"sync/atomic"
	"time"

	cache "github.com/fdurand/go-cache"
	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/go-radius"
	"github.com/inverse-inc/go-radius/rfc2866"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/mac"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/tryableonce"
	statsd "gopkg.in/alexcesaro/statsd.v2"
)

const DefaultTimeDuration = 5 * time.Minute
const DefaultRadiusWorkQueueSize = 1000
const DefaultAAANotifyQueueSize = 1000

type radiusRequest struct {
	w          radius.ResponseWriter
	r          *radius.Request
	switchInfo *SwitchInfo
	status     rfc2866.AcctStatusType
	mac        mac.Mac
}

type PfAcct struct {
	RadiusStatements
	TimeDuration            time.Duration
	Db                      *sql.DB
	AllowedNetworks         []net.IPNet
	NetFlowPort             string
	NetFlowAddress          string
	Management              pfconfigdriver.ManagementNetwork
	AAAClient               *jsonrpc2.Client
	LoggerCtx               context.Context
	Dispatcher              *Dispatcher
	SwitchInfoCache         *cache.Cache
	NodeSessionCache        *cache.Cache
	AcctSessionCache        *cache.Cache
	RateLimitCache          *cache.Cache
	MacNasCache             *cache.Cache
	RateLimit               bool
	PfacctRateLimitCacheTtl int
	StatsdAddress           string
	StatsdOption            statsd.Option
	StatsdClient            *statsd.Client
	radiusRequests          []chan<- radiusRequest
	aaaNotifyQueues         []chan<- aaaNotifyJob
	aaaNotifyDropped        atomic.Int64
	localSecret             string
	StatsdOnce              tryableonce.TryableOnce
	isProxied               bool
	radiusdAcctEnabled      bool
	AllNetworks             bool
	ProcessBandwidthAcct    bool
	RadiusWorkers           int
	RadiusWorkQueueSize     int
	SocketRecvBuffer        int
	AAANotifyWorkers        int
	AAANotifyQueueSize      int
}

func NewPfAcct(logLevel string) *PfAcct {
	var ctx = context.Background()
	ctx = log.LoggerNewContext(ctx)
	ctx = log.LoggerSetLevel(ctx, logLevel)

	Database, err := db.DbFromConfig(ctx)
	for err != nil {
		logError(ctx, "Error: "+err.Error())
		time.Sleep(time.Duration(5) * time.Second)
		Database, err = db.DbFromConfig(ctx)
	}

	err = Database.Ping()
	for err != nil {
		time.Sleep(time.Duration(5) * time.Second)
		err = Database.Ping()
	}

	pfAcct := &PfAcct{
		Db:                  Database,
		TimeDuration:        DefaultTimeDuration,
		RadiusWorkQueueSize: DefaultRadiusWorkQueueSize,
		AAANotifyQueueSize:  DefaultAAANotifyQueueSize,
	}
	pfAcct.SwitchInfoCache = cache.New(5*time.Minute, 10*time.Minute)
	pfAcct.NodeSessionCache = cache.New(cache.NoExpiration, cache.NoExpiration)
	pfAcct.AcctSessionCache = cache.New(5*time.Minute, 10*time.Minute)

	pfAcct.LoggerCtx = ctx
	pfAcct.RadiusStatements.Setup(pfAcct.Db)

	pfAcct.SetupConfig(ctx)
	pfAcct.radiusRequests = makeRadiusRequests(pfAcct, pfAcct.RadiusWorkers, pfAcct.RadiusWorkQueueSize)
	pfAcct.AAAClient = jsonrpc2.NewAAAClientFromConfig(ctx)
	pfAcct.aaaNotifyQueues = makeAAANotifiers(pfAcct, pfAcct.AAANotifyWorkers, pfAcct.AAANotifyQueueSize)
	//pfAcct.Dispatcher = NewDispatcher(16, 128)

	pfAcct.runPing()
	pfAcct.reportAAADrops()
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

// aaaNotifyJob carries a pre-serialized radius_accounting notification to the
// dedicated AAA notifier pool.
type aaaNotifyJob struct {
	ctx  context.Context
	attr map[string]interface{}
}

// makeAAANotifiers builds a MAC-sharded pool of workers that forward
// radius_accounting notifications to httpd.aaa. Decoupling this (potentially
// remote and slow) call from the accounting workers keeps the node
// online/offline DB updates current even when httpd.aaa is overloaded, while
// sharding by MAC preserves per-device ordering of the notifications.
func makeAAANotifiers(h *PfAcct, workers, backlog int) []chan<- aaaNotifyJob {
	queues := make([]chan<- aaaNotifyJob, workers)
	for i := 0; i < workers; i++ {
		c := make(chan aaaNotifyJob, backlog)
		queues[i] = c
		go func(c <-chan aaaNotifyJob) {
			for job := range c {
				if err := h.AAAClient.Notify(job.ctx, "radius_accounting", job.attr); err != nil {
					logError(job.ctx, err.Error())
				}
			}
		}(c)
	}

	return queues
}

// reportAAADrops periodically logs how many radius_accounting notifications
// were dropped because the notifier queues were saturated. Drops here do not
// affect node online/offline status (written synchronously by the accounting
// workers); they only mean some accounting side effects (ip4log, locationlog,
// triggers) were skipped while httpd.aaa could not keep up.
func (pfAcct *PfAcct) reportAAADrops() {
	go func() {
		for {
			time.Sleep(60 * time.Second)
			if dropped := pfAcct.aaaNotifyDropped.Swap(0); dropped > 0 {
				logWarn(pfAcct.LoggerCtx, fmt.Sprintf("Dropped %d radius_accounting notifications in the last 60s because the AAA notify queue was full (httpd.aaa may be overloaded); node online/offline status is unaffected", dropped))
			}
		}
	}()
}

func (pfAcct *PfAcct) SetupConfig(ctx context.Context) {
	numOfCpus := runtime.NumCPU()
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
	pfAcct.AllNetworks = sharedutils.IsEnabled(keyConfAdvanced.NetFlowOnAllNetworks)
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
	var RadiusConfiguration pfconfigdriver.PfConfRadiusConfiguration
	pfconfigdriver.FetchDecodeSocket(ctx, &RadiusConfiguration)
	pfAcct.ProcessBandwidthAcct = sharedutils.IsEnabled(RadiusConfiguration.ProcessBandwidthAccounting)
	if i, err := strconv.Atoi(RadiusConfiguration.PfacctRateLimitCacheTtl); err == nil {
		pfAcct.PfacctRateLimitCacheTtl = i
	}
	pfAcct.RateLimitCache = cache.New(time.Duration(pfAcct.PfacctRateLimitCacheTtl)*time.Minute, 10*time.Minute)
	pfAcct.MacNasCache = cache.New(time.Duration(pfAcct.PfacctRateLimitCacheTtl)*time.Minute, 10*time.Minute)
	if !pfAcct.ProcessBandwidthAcct {
		logInfo(ctx, "Not processing bandwidth accounting records. To enable set radius_configuration.process_bandwidth_accounting = enabled")
	}

	if i, err := strconv.ParseInt(RadiusConfiguration.PfacctWorkers, 10, 64); err != nil {
		logWarn(ctx, fmt.Sprintf("Invalid number '%s' pfacct_worker defaulting to '%d'", RadiusConfiguration.PfacctWorkers, pfAcct.RadiusWorkers))
	} else {
		pfAcct.RadiusWorkers = int(i)
	}

	// If set to zero use twice the number of CPUs for the workers
	pfAcct.RadiusWorkers = cmp.Or(pfAcct.RadiusWorkers, 2*numOfCpus)

	if i, err := strconv.ParseInt(RadiusConfiguration.PfacctWorkQueueSize, 10, 64); err != nil {
		logWarn(ctx, fmt.Sprintf("Invalid number '%s' pfacct_work_queue_size defaulting to '%d'", RadiusConfiguration.PfacctWorkQueueSize, pfAcct.RadiusWorkQueueSize))
	} else {
		pfAcct.RadiusWorkQueueSize = int(i)
	}

	// Size (in bytes) of the UDP socket receive buffer requested via SO_RCVBUF.
	// The kernel caps the effective value at net.core.rmem_max. Zero leaves the
	// OS default (net.core.rmem_default) in place.
	if i, err := strconv.ParseInt(RadiusConfiguration.PfacctSocketRecvBuffer, 10, 64); err != nil {
		logWarn(ctx, fmt.Sprintf("Invalid number '%s' pfacct_socket_recv_buffer, leaving the OS default UDP receive buffer in place", RadiusConfiguration.PfacctSocketRecvBuffer))
	} else {
		pfAcct.SocketRecvBuffer = int(i)
	}

	if i, err := strconv.ParseInt(RadiusConfiguration.PfacctAAANotifyWorkers, 10, 64); err != nil {
		logWarn(ctx, fmt.Sprintf("Invalid number '%s' pfacct_aaa_notify_workers defaulting to '%d'", RadiusConfiguration.PfacctAAANotifyWorkers, pfAcct.AAANotifyWorkers))
	} else {
		pfAcct.AAANotifyWorkers = int(i)
	}

	// If set to zero use twice the number of CPUs for the AAA notifier pool
	pfAcct.AAANotifyWorkers = cmp.Or(pfAcct.AAANotifyWorkers, 2*numOfCpus)

	if i, err := strconv.ParseInt(RadiusConfiguration.PfacctAAANotifyQueueSize, 10, 64); err != nil {
		logWarn(ctx, fmt.Sprintf("Invalid number '%s' pfacct_aaa_notify_queue_size defaulting to '%d'", RadiusConfiguration.PfacctAAANotifyQueueSize, pfAcct.AAANotifyQueueSize))
	} else {
		pfAcct.AAANotifyQueueSize = int(i)
	}

	pfAcct.AAANotifyQueueSize = cmp.Or(pfAcct.AAANotifyQueueSize, DefaultAAANotifyQueueSize)

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
				logDebug(pfAcct.LoggerCtx, "Unable to ping DB: "+err.Error())
			} else {
				logDebug(pfAcct.LoggerCtx, "Pinged DB")
			}
		}
	}(pfAcct)
}

func (pfAcct *PfAcct) SendGauge(name string, val int) {
	if pfAcct.StatsdClient == nil {
		return
	}

	pfAcct.StatsdClient.Gauge(name, val)
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

type AcctSession struct {
	in_bytes  int64
	out_bytes int64
}

func (pfAcct *PfAcct) SetAcctSession(node_id, unique_session uint64, session *AcctSession) {
	key := fmt.Sprintf("%x:%x", node_id, unique_session)
	pfAcct.AcctSessionCache.Set(key, session, cache.DefaultExpiration)
}

func (pfAcct *PfAcct) GetAcctSession(node_id, unique_session uint64) *AcctSession {
	key := fmt.Sprintf("%x:%x", node_id, unique_session)
	if s, found := pfAcct.AcctSessionCache.Get(key); found {
		return s.(*AcctSession)
	}
	return nil
}
