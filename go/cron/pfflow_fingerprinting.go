package maint

import (
	"context"
	"database/sql"
	"net/netip"
	"sync"
	"time"

	"github.com/fdurand/go-cache"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/mac"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
)

var fingerPrintingJobOnce sync.Once

var fingerprintChan chan []*PfFlows

type FingerPrintingJob struct {
	fingerprintChan <-chan []*PfFlows
	stopChan        chan struct{}
	nodeCache       *cache.Cache
	db              *sql.DB
	networks        []netip.Prefix
	Ctx             context.Context
}

func NewFingerPrintingJobOptions(config map[string]interface{}) *FingerPrintingJobOptions {
	options := &FingerPrintingJobOptions{}
	options.Ctx = context.Background()
	options.CacheExpiration = time.Duration(int(config["fingerprint_cache_expiration"].(float64))) * time.Second
	options.FingerprintChan = make(chan []*PfFlows, 1000)
	options.StopChan = make(chan struct{})
	options.Fingerprint = sharedutils.ISENABLED[config["fingerprint"].(string)]
	db, err := getDb()
	if err != nil {
		panic(err)
	}

	options.DB = db
	network_strings := interfaceArrayToStringArray(config["fingerprint_networks"].([]interface{}))
	networks := []netip.Prefix{}

	for _, n := range network_strings {
		networks = append(networks, netip.MustParsePrefix(n))
	}
	options.Networks = networks

	return options
}

type FingerPrintingJobOptions struct {
	FingerprintChan chan []*PfFlows
	Fingerprint     bool
	StopChan        chan struct{}
	CacheExpiration time.Duration
	Networks        []netip.Prefix
	DB              *sql.DB
	Ctx             context.Context
}

func NewFingerPrintingJob(options *FingerPrintingJobOptions) *FingerPrintingJob {
	return &FingerPrintingJob{
		stopChan:        options.StopChan,
		fingerprintChan: options.FingerprintChan,
		nodeCache:       cache.New(options.CacheExpiration, options.CacheExpiration),
		networks:        options.Networks,
		db:              options.DB,
		Ctx:             options.Ctx,
	}
}

type NodeInfo struct {
	Mac  mac.Mac
	Ip   netip.Addr
	Port uint16
}

func toNodeInfo(macStr string, ip netip.Addr, port uint16) *NodeInfo {
	mac, err := mac.NewFromString(macStr)
	if err != nil {
		return nil
	}

	return &NodeInfo{
		Mac:  mac,
		Ip:   ip,
		Port: port,
	}
}

func (f *FingerPrintingJob) getMacInfo(pf *PfFlow) (*NodeInfo, *NodeInfo) {
	return toNodeInfo(pf.SrcMac, pf.SrcIp, pf.SrcPort), toNodeInfo(pf.DstMac, pf.DstIp, pf.DstPort)
}

func IsInNetwork(ctx context.Context, networks []netip.Prefix, ip netip.Addr) bool {
	if !ip.IsValid() {
		log.LogDebugf(ctx, "IsInNetwork: Invalid IP address: %s", ip)
		return false
	}

	if len(networks) == 0 {
		log.LogDebugf(ctx, "IsInNetwork: No networks defined, returning true for IP: %s", ip)
		return true
	}

	for _, n := range networks {
		if n.Contains(ip) {
			log.LogDebugf(ctx, "IsInNetwork: IP %s is in network %s", ip, n)
			return true
		}
	}

	log.LogDebugf(ctx, "IsInNetwork: IP %s is not in any network", ip)
	return false
}

func (f *FingerPrintingJob) skip(p *NodeInfo) bool {
	log.LogDebugf(f.Ctx, "Checking if NodeInfo should be skipped: MAC=%s, IP=%s", p.Mac.String(), p.Ip.String())
	if p == nil || p.Mac.IsZero() || p.Ip.IsUnspecified() || !p.Ip.IsValid() || !IsInNetwork(f.Ctx, f.networks, p.Ip) {
		log.LogDebug(f.Ctx, "NodeInfo is invalid or not in network, skipping")
		return true
	}

	if _, found := f.nodeCache.Get(p.Mac.String()); found {
		log.LogDebugf(f.Ctx, "NodeInfo with MAC %s is already in cache, skipping", p.Mac.String())
		return true
	}

	if err := f.nodeCache.Add(p.Mac.String(), &struct{}{}, 0); err != nil {
		log.LogDebugf(f.Ctx, "Failed to add NodeInfo with MAC %s to cache: %s", p.Mac.String(), err)
		return true
	}

	log.LogDebugf(f.Ctx, "NodeInfo with MAC %s is valid and not in cache, processing", p.Mac.String())
	return false
}

func (f *FingerPrintingJob) handleFlow(pfflow *PfFlow) {
	log.LogDebugf(f.Ctx, "Handling flow: %+v", pfflow)
	srcNode, dstNode := f.getMacInfo(pfflow)
	if srcNode != nil {
		f.handleNodeInfo(srcNode)
	}
	if dstNode != nil {
		f.handleNodeInfo(dstNode)
	}
}

func (f *FingerPrintingJob) fingerPrint(nodeInfo *NodeInfo) {
	log.LogDebugf(f.Ctx, "Sending fingerprint request for NodeInfo: MAC=%s, IP=%s", nodeInfo.Mac.String(), nodeInfo.Ip.String())
	client := jsonrpc2.NewClientFromConfig(f.Ctx)
	client.Notify(
		f.Ctx,
		"fingerbank_process",
		[]interface{}{nodeInfo.Mac.String()},
	)
}

func (f *FingerPrintingJob) handleNodeInfo(nodeInfo *NodeInfo) {
	log.LogDebugf(f.Ctx, "Handling NodeInfo: MAC=%s, IP=%s", nodeInfo.Mac.String(), nodeInfo.Ip.String())
	if !f.skip(nodeInfo) {
		log.LogDebugf(f.Ctx, "Adding NodeInfo to database and sending fingerprint request: MAC=%s, IP=%s", nodeInfo.Mac.String(), nodeInfo.Ip.String())
		f.addNode(nodeInfo)
		f.fingerPrint(nodeInfo)
	} else {
		log.LogDebugf(f.Ctx, "NodeInfo skipped: MAC=%s, IP=%s", nodeInfo.Mac.String(), nodeInfo.Ip.String())
	}
}

func (f *FingerPrintingJob) addNode(node *NodeInfo) {
	log.LogDebugf(f.Ctx, "Adding NodeInfo to database: MAC=%s, IP=%s", node.Mac.String(), node.Ip.String())
	if _, err := f.db.Exec("INSERT IGNORE INTO node (mac, pid, last_seen, detect_date, status) VALUES (?, 'default', NOW(), NOW(), 'unreg')", node.Mac.String()); err != nil {
		log.LogErrorf(f.Ctx, "Error adding NodeInfo to node table: %s", err.Error())
	}

	if _, err := f.db.Exec("INSERT IGNORE INTO ip4log (mac, ip) VALUES (?, ?)", node.Mac.String(), node.Ip.String()); err != nil {
		log.LogErrorf(f.Ctx, "Error adding NodeInfo to ip4log table: %s", err.Error())
	}
}

func SetupFingerPrintingJob(config map[string]interface{}) chan []*PfFlows {
	fingerPrintingJobOnce.Do(func() {
		options := NewFingerPrintingJobOptions(config)
		if !options.Fingerprint {
			log.LogDebugf(options.Ctx, "Fingerprinting is disabled, not starting fingerprint job")
			return
		}
		log.LogDebugf(options.Ctx, "Fingerprinting is enabled, starting fingerprint job")
		fingerprintChan = options.FingerprintChan
		fb := NewFingerPrintingJob(options)
		go fb.Run()
	})

	return fingerprintChan
}

func (f *FingerPrintingJob) handleFlows(pfflows []*PfFlows) {
	log.LogDebugf(f.Ctx, "Handling flows: %+v", pfflows)
	for _, flows := range pfflows {
		for _, flow := range *flows.Flows {
			log.LogDebugf(f.Ctx, "Processing flow: %+v", flow)
			f.handleFlow(&flow)
		}
	}
}

func (f *FingerPrintingJob) RunWithContext(ctx context.Context) {
	f.Ctx = ctx
	log.LogDebug(f.Ctx, "Starting FingerPrintingJob")
	for {
		select {
		case <-f.stopChan:
			log.LogDebug(f.Ctx, "Stop signal received, draining fingerprintChan")
			for pfflows := range f.fingerprintChan {
				log.LogDebugf(f.Ctx, "Draining flows: %+v", pfflows)
				f.handleFlows(pfflows)
			}
			close(f.stopChan)
			log.LogDebug(f.Ctx, "FingerPrintingJob stopped")
			return
		case pfflows := <-f.fingerprintChan:
			log.LogDebugf(f.Ctx, "Received flows from fingerprintChan: %+v", pfflows)
			f.handleFlows(pfflows)
		}
	}
}

func (f *FingerPrintingJob) Run() {
	f.RunWithContext(context.Background())
}

func (f *FingerPrintingJob) Stop() {
	log.LogDebug(f.Ctx, "Stopping FingerPrintingJob")
	f.stopChan <- struct{}{}
	<-f.stopChan
	log.LogDebug(f.Ctx, "FingerPrintingJob stopped")
}
