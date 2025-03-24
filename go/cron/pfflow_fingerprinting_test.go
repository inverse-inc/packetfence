package maint

import (
	"net/netip"
	"testing"
	"time"

	"github.com/google/go-cmp/cmp"
	"github.com/inverse-inc/go-utils/mac"
)

func TestFingerPrintingJob(t *testing.T) {
	events := []*PfFlows{
		{
			Header: PfFlowHeader{
				DomainID: 1,
				FlowSeq:  1,
			},
			Flows: &[]PfFlow{
				{
					SrcMac:          "00:11:22:33:44:55",
					DstMac:          "00:11:22:33:44:56",
					SrcIp:           netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					DstIp:           netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					SrcPort:         80,
					DstPort:         1025,
					Proto:           6,
					BiFlow:          2,
					ConnectionCount: 2,
				},
				{
					SrcMac:          "00:11:22:33:44:56",
					DstMac:          "00:11:22:33:44:55",
					SrcIp:           netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					DstIp:           netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					SrcPort:         1024,
					DstPort:         80,
					Proto:           6,
					BiFlow:          1,
					ConnectionCount: 2,
				},
				{
					SrcMac:          "00:11:22:33:44:55",
					DstMac:          "00:11:22:33:44:56",
					SrcIp:           netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					DstIp:           netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					SrcPort:         80,
					DstPort:         1024,
					Proto:           6,
					BiFlow:          2,
					ConnectionCount: 2,
				},
				{
					SrcMac:          "00:11:22:33:44:56",
					DstMac:          "00:11:22:33:44:55",
					SrcIp:           netip.AddrFrom4([4]byte{1, 1, 1, 1}),
					DstIp:           netip.AddrFrom4([4]byte{1, 1, 1, 2}),
					SrcPort:         1025,
					DstPort:         80,
					Proto:           6,
					BiFlow:          1,
					ConnectionCount: 2,
				},
			},
		},
	}
	db, err := getDb()
	if err != nil {
		t.Fatalf("Cannot get database: %s", err.Error())
	}

	options := FingerPrintingJobOptions{
		FingerprintChan: make(chan []*PfFlows, 100),
		StopChan:        make(chan struct{}),
		CacheExpiration: time.Minute * 5,
		Networks:        []netip.Prefix{
			//			netip.MustParsePrefix("1.1.1.0/24"),
		},
		DB: db,
	}

	fb := NewFingerPrintingJob(&options)
	options.FingerprintChan <- events
	go fb.Run()
	close(options.FingerprintChan)
	fb.Stop()
	src, dst := fb.getMacInfo(&(*events[0].Flows)[0])
	if !fb.skip(src) {
		t.Errorf("Src Node info not skipped %s", src.Mac.String())
	}

	if !fb.skip(dst) {
		t.Errorf("Dst Node info not skipped %s", dst.Mac.String())
	}
}

func TestNodeInfo(t *testing.T) {

	flow := PfFlow{
		SrcMac:          "00:11:22:33:44:55",
		DstMac:          "00:11:22:33:44:56",
		SrcIp:           netip.AddrFrom4([4]byte{1, 1, 1, 2}),
		DstIp:           netip.AddrFrom4([4]byte{1, 1, 1, 1}),
		SrcPort:         80,
		DstPort:         1025,
		Proto:           6,
		BiFlow:          2,
		ConnectionCount: 2,
	}
	fb := FingerPrintingJob{}
	src, dst := fb.getMacInfo(&flow)
	if diff := cmp.Diff(
		src, &NodeInfo{
			Mac:  mac.Mac([6]byte{0x00, 0x11, 0x22, 0x33, 0x44, 0x55}),
			Ip:   netip.AddrFrom4([4]byte{1, 1, 1, 2}),
			Port: 80,
		},
		cmp.Comparer(func(x, y netip.Addr) bool {
			return x == y
		})); diff != "" {
		t.Fatalf("%s not equal %s", "Src NodeInfo does not match", diff)
	}

	if diff := cmp.Diff(
		dst, &NodeInfo{
			Mac:  mac.Mac([6]byte{0x00, 0x11, 0x22, 0x33, 0x44, 0x56}),
			Ip:   netip.AddrFrom4([4]byte{1, 1, 1, 1}),
			Port: 1025,
		},
		cmp.Comparer(func(x, y netip.Addr) bool {
			return x == y
		})); diff != "" {
		t.Fatalf("%s not equal %s", "Dst NodeInfo does not match", diff)
	}
}
