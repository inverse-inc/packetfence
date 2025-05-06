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
	"github.com/inverse-inc/packetfence/go/jsonrpc2"
)

var fingerPrintingJobOnce sync.Once

type FingerPrintingJob struct {
	fingerprintChan <-chan []*PfFlows
	stopChan        chan struct{}
	nodeCache       *cache.Cache
	db              *sql.DB
	networks        []netip.Prefix
}

func NewFingerPrintingJobOptions(config map[string]interface{}) *FingerPrintingJobOptions {
	options := &FingerPrintingJobOptions{}
	options.CacheExpiration = time.Duration(int(config["fingerprint_cache_expiration"].(float64))) * time.Second
	options.FingerprintChan = make(chan []*PfFlows, 1000)
	options.StopChan = make(chan struct{})
	options.Fingerprint = defaultIntConfig(config, "fingerprint", 0)
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
	Fingerprint     int
	StopChan        chan struct{}
	CacheExpiration time.Duration
	Networks        []netip.Prefix
	DB              *sql.DB
}

func NewFingerPrintingJob(options *FingerPrintingJobOptions) *FingerPrintingJob {
	return &FingerPrintingJob{
		stopChan:        options.StopChan,
		fingerprintChan: options.FingerprintChan,
		nodeCache:       cache.New(options.CacheExpiration, options.CacheExpiration),
		networks:        options.Networks,
		db:              options.DB,
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

func IsInNetwork(networks []netip.Prefix, ip netip.Addr) bool {
	if len(networks) == 0 {
		return true
	}

	for _, n := range networks {
		if n.Contains(ip) {
			return true
		}
	}

	return false
}

func (f *FingerPrintingJob) skip(p *NodeInfo) bool {
	if p == nil || p.Mac.IsZero() || p.Ip.IsUnspecified() || !p.Ip.IsValid() || !IsInNetwork(f.networks, p.Ip) {
		return true
	}

	if _, found := f.nodeCache.Get(p.Mac.String()); found {
		return true
	}

	return f.nodeCache.Add(p.Mac.String(), &struct{}{}, 0) != nil
}

func (f *FingerPrintingJob) handleFlow(pfflow *PfFlow) {
	ctx := context.Background()
	srcNode, dstNode := f.getMacInfo(pfflow)
	f.handleNodeInfo(ctx, srcNode)
	f.handleNodeInfo(ctx, dstNode)
}

func (f *FingerPrintingJob) fingerPrint(ctx context.Context, nodeInfo *NodeInfo) {
	client := jsonrpc2.NewClientFromConfig(ctx)
	client.Notify(
		ctx,
		"fingerbank_process",
		[]interface{}{nodeInfo.Mac.String()},
	)

}

func (f *FingerPrintingJob) handleNodeInfo(ctx context.Context, nodeInfo *NodeInfo) {
	if !f.skip(nodeInfo) {
		f.addNode(ctx, nodeInfo)
		f.fingerPrint(ctx, nodeInfo)
	}
}

func (f *FingerPrintingJob) addNode(ctx context.Context, node *NodeInfo) {
	if _, err := f.db.Exec("INSERT IGNORE INTO node (mac, pid, last_seen, detect_date, status) VALUES (?, 'default', NOW(), NOW(), 'unreg')", node.Mac.String()); err != nil {
		log.LogErrorf(ctx, "Error: %s", err.Error())
	}

	if _, err := f.db.Exec("INSERT IGNORE INTO ip4log (mac, ip) VALUES (?, ?)", node.Mac.String(), node.Ip.String()); err != nil {
		log.LogErrorf(ctx, "Error: %s", err.Error())
	}
}

func SetupFingerPrintingJob(config map[string]interface{}) chan []*PfFlows {
	var pfflow_chan chan []*PfFlows
	fingerPrintingJobOnce.Do(func() {
		options := NewFingerPrintingJobOptions(config)
		if options.Fingerprint == 0 {
			return
		}

		pfflow_chan = options.FingerprintChan
		fb := NewFingerPrintingJob(options)
		go fb.Run()
	})

	return pfflow_chan
}

func (f *FingerPrintingJob) handleFlows(pfflows []*PfFlows) {
	for _, flows := range pfflows {
		for _, flow := range *flows.Flows {
			f.handleFlow(&flow)
		}
	}
}

func (f *FingerPrintingJob) Run() {
LOOP:
	for {
		select {
		case <-f.stopChan:
			break LOOP
		case pfflows := <-f.fingerprintChan:
			f.handleFlows(pfflows)
		}
	}

	for pfflows := range f.fingerprintChan {
		f.handleFlows(pfflows)
	}

	close(f.stopChan)
}

func (f *FingerPrintingJob) Stop() {
	f.stopChan <- struct{}{}
	<-f.stopChan
}
