package main

import (
	"github.com/inverse-inc/packetfence/go/netflow5"
	"testing"
)

func TestNetFlowV5ToBandwidthAccounting(t *testing.T) {
	flow := netflow5.NetFlow5{}
	ba := NetFlowV5ToBandwidthAccounting(&flow.Header, flow.FlowArray())
	_ = ba

}
