package maint

import (
	"net/netip"
	"testing"
)

func TestPfFlowDenyDetection(t *testing.T) {
	header := PfFlowHeader{DomainID: 1, FlowSeq: 42}

	cases := []struct {
		name            string
		snmpIndexOutput uint16
		wantDenied      bool
		wantEventType   NetworkEventType
	}{
		{
			name:            "snmp_index_output zero is treated as deny",
			snmpIndexOutput: 0,
			wantDenied:      true,
			wantEventType:   NetworkEventTypeFailed,
		},
		{
			name:            "non-zero snmp_index_output is treated as permit",
			snmpIndexOutput: 5,
			wantDenied:      false,
			wantEventType:   NetworkEventTypeSuccessful,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := PfFlow{
				SrcIp:           netip.AddrFrom4([4]byte{10, 0, 0, 1}),
				DstIp:           netip.AddrFrom4([4]byte{10, 0, 0, 2}),
				SrcMac:          "aa:bb:cc:dd:ee:01",
				DstMac:          "aa:bb:cc:dd:ee:02",
				DstPort:         80,
				Proto:           6,
				SnmpIndexOutput: tc.snmpIndexOutput,
			}

			if got := f.Key(&header).Denied; got != tc.wantDenied {
				t.Errorf("Key().Denied = %v, want %v", got, tc.wantDenied)
			}

			ne := f.ToNetworkEvent()
			if ne == nil {
				t.Fatalf("ToNetworkEvent returned nil")
			}
			if ne.EventType != tc.wantEventType {
				t.Errorf("ToNetworkEvent().EventType = %q, want %q", ne.EventType, tc.wantEventType)
			}
		})
	}
}
