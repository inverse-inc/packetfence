package maint

import (
	"context"
	"database/sql"
	"fmt"
	"net/netip"
	"time"

	"github.com/inverse-inc/go-utils/log"
)

type EventKey struct {
	DomainID  uint32
	FlowSeq   uint32
	SrcIp     netip.Addr
	DstIp     netip.Addr
	DstPort   uint16
	Proto     uint8
	HasBiFlow bool
}

func NewAggregator(o *AggregatorOptions) *Aggregator {
	return &Aggregator{
		timeout:          o.Timeout,
		backlog:          1000,
		networkEventChan: o.NetworkEventChan,
		events:           make(map[EventKey][]PfFlow),
		stop:             make(chan struct{}),
		PfFlowsChan:      ChanPfFlow,
		Heuristics:       o.Heuristics,
		db:               o.Db,
		flushChan:        make(chan flushBatch, 1),
	}
}

type AggregatorOptions struct {
	NetworkEventChan chan []*NetworkEvent
	Timeout          time.Duration
	Heuristics       bool
	Db               *sql.DB
}

type AggregatorSession struct {
	SessionId uint32
	Port      uint16
}

type Aggregator struct {
	events           map[EventKey][]PfFlow
	PfFlowsChan      chan []*PfFlows
	stop             chan struct{}
	networkEventChan chan []*NetworkEvent
	backlog          int
	timeout          time.Duration
	Heuristics       bool
	db               *sql.DB
	flushChan        chan flushBatch
}

func emptyMac(mac string) bool {
	return mac == "00:00:00:00:00:00" || mac == ""
}

func flowType(t uint16) string {
	switch t {
	case 5:
		return "Netflow(5)"
	case 9:
		return "Netflow(9)"
	case 10:
		return "Netflow(10)"
	case 65535:
		return "Sflow"
	default:
		return fmt.Sprintf("unknown(%d)", t)
	}
}

func protoToString(t uint8) string {
	switch t {
	default:
		return "Unassigned/Reserved"
	case 0:
		return "HOPOPT"
	case 1:
		return "ICMP"
	case 2:
		return "IGMP"
	case 3:
		return "GGP"
	case 4:
		return "IP-in-IP"
	case 5:
		return "ST"
	case 6:
		return "TCP"
	case 7:
		return "CBT"
	case 8:
		return "EGP"
	case 9:
		return "IGP"
	case 10:
		return "BBN-RCC-MON"
	case 11:
		return "NVP-II"
	case 12:
		return "PUP"
	case 13:
		return "ARGUS"
	case 14:
		return "EMCON"
	case 15:
		return "XNET"
	case 16:
		return "CHAOS"
	case 17:
		return "UDP"
	case 18:
		return "MUX"
	case 19:
		return "DCN-MEAS"
	case 20:
		return "HMP"
	case 21:
		return "PRM"
	case 22:
		return "XNS-IDP"
	case 23:
		return "TRUNK-1"
	case 24:
		return "TRUNK-2"
	case 25:
		return "LEAF-1"
	case 26:
		return "LEAF-2"
	case 27:
		return "RDP"
	case 28:
		return "IRTP"
	case 29:
		return "ISO-TP"
	case 30:
		return "NETBLT"
	case 31:
		return "MFE-NSP"
	case 32:
		return "MERIT-INP"
	case 33:
		return "DCCP"
	case 34:
		return "3PC"
	case 35:
		return "IDPR"
	case 36:
		return "XTP"
	case 37:
		return "DDP"
	case 38:
		return "IDPR-CMTP"
	case 39:
		return "TP++"
	case 40:
		return "IL"
	case 41:
		return "IPv"
	case 42:
		return "SDRP"
	case 43:
		return "IPv"
	case 44:
		return "IPv"
	case 45:
		return "IDRP"
	case 46:
		return "RSVP"
	case 47:
		return "GRE"
	case 48:
		return "DSR"
	case 49:
		return "BNA"
	case 50:
		return "ESP"
	case 51:
		return "AH"
	case 52:
		return "I-NLSP"
	case 53:
		return "SwIPe"
	case 54:
		return "NARP"
	case 55:
		return "MOBILE"
	case 56:
		return "TLSP"
	case 57:
		return "SKIP"
	case 58:
		return "IPv"
	case 59:
		return "IPv"
	case 60:
		return "IPv"
	case 61:
		return "Any host internal protocol	"
	case 62:
		return "CFTP"
	case 63:
		return "Any local network"
	case 64:
		return "SAT-EXPAK"
	case 65:
		return "KRYPTOLAN"
	case 66:
		return "RVD"
	case 67:
		return "IPPC"
	case 68:
		return "Any distributed file system"
	case 69:
		return "SAT-MON"
	case 70:
		return "VISA"
	case 71:
		return "IPCU"
	case 72:
		return "CPNX"
	case 73:
		return "CPHB"
	case 74:
		return "WSN"
	case 75:
		return "PVP"
	case 76:
		return "BR-SAT-MON"
	case 77:
		return "SUN-ND"
	case 78:
		return "WB-MON"
	case 79:
		return "WB-EXPAK"
	case 80:
		return "ISO-IP"
	case 81:
		return "VMTP"
	case 82:
		return "SECURE-VMTP"
	case 83:
		return "VINES"
	case 84:
		return "IPTM"
	case 85:
		return "NSFNET-IGP"
	case 86:
		return "DGP"
	case 87:
		return "TCF"
	case 88:
		return "EIGRP"
	case 89:
		return "OSPF"
	case 90:
		return "Sprite-RPC"
	case 91:
		return "LARP"
	case 92:
		return "MTP"
	case 93:
		return "AX"
	case 94:
		return "OS"
	case 95:
		return "MICP"
	case 96:
		return "SCC-SP"
	case 97:
		return "ETHERIP"
	case 98:
		return "ENCAP"
	case 99:
		return "Any private encryption scheme"
	case 100:
		return "GMTP"
	case 101:
		return "IFMP"
	case 102:
		return "PNNI"
	case 103:
		return "PIM"
	case 104:
		return "ARIS"
	case 105:
		return "SCPS"
	case 106:
		return "QNX"
	case 107:
		return "A/N"
	case 108:
		return "IPComp"
	case 109:
		return "SNP"
	case 110:
		return "Compaq-Peer"
	case 111:
		return "IPX-in-IP"
	case 112:
		return "VRRP"
	case 113:
		return "PGM"
	case 114:
		return "0-hop-protocol"
	case 115:
		return "L"
	case 116:
		return "DDX"
	case 117:
		return "IATP"
	case 118:
		return "STP"
	case 119:
		return "SRP"
	case 120:
		return "UTI"
	case 121:
		return "SMP"
	case 122:
		return "SM"
	case 123:
		return "PTP"
	case 124:
		return "IS-IS"
	case 125:
		return "FIRE"
	case 126:
		return "CRTP"
	case 127:
		return "CRUDP"
	case 128:
		return "SSCOPMCE"
	case 129:
		return "IPLT"
	case 130:
		return "SPS"
	case 131:
		return "PIPE"
	case 132:
		return "SCTP"
	case 133:
		return "FC"
	case 134:
		return "RSVP-E"
	case 135:
		return "Mobility"
	case 136:
		return "UDPLite"
	case 137:
		return "MPLS-in-IP"
	case 138:
		return "manet"
	case 139:
		return "HIP"
	case 140:
		return "Shim"
	case 141:
		return "WESP"
	case 142:
		return "ROHC"
	case 143:
		return "Ethernet"
	case 144:
		return "AGGFRAG"
	case 145:
		return "NSH"
	}
}

func logPfFlow(ctx context.Context, header *PfFlowHeader, f *PfFlow) {
	log.LogInfof(
		ctx,
		"Received PfFlow %s SrcMac: %s, SrcIP: %s, SrcPort: %d, DstMac: %s, DstIp: %s, DstPort: %d, BiFlow: %d, Proto: %s",
		flowType(header.FlowType),
		f.SrcMac, f.SrcIp.String(), f.SrcPort,
		f.DstMac, f.DstIp.String(), f.DstPort,
		f.BiFlow,
		protoToString(f.Proto),
	)
}

func (a *Aggregator) handleEvents() {
	// A context carrying a logger: with a bare context every Log*f call
	// rebuilds a logger (including a syslog dial) before filtering the line.
	ctx := log.LoggerNewContext(context.Background())
	ticker := time.NewTicker(a.timeout)
	defer ticker.Stop()

	go a.flusher(ctx)
	defer close(a.flushChan)

	stats := newWindowStats()
loop:
	for {
		select {
		case pfflowsArray := <-a.PfFlowsChan:
			for _, pfflows := range pfflowsArray {
				if pfflows.Flows == nil {
					continue
				}

				stats.messages++
				stats.flows += len(*pfflows.Flows)
				// The agent address is the exporter (switch) IP. Older collectors
				// leave it unset for NetFlow/IPFIX ("invalid IP") and an sFlow
				// exporter without an agent-ip sends 0.0.0.0; neither is a switch.
				// Marked as seen once per window by the flusher, off this goroutine.
				if addr := pfflows.Header.AgentAddr; addr.IsValid() && !addr.IsUnspecified() {
					stats.noteAgent(addr.String())
				}

				for _, f := range *pfflows.Flows {
					if a.Heuristics {
						f.Heuristics()
					}

					key := f.Key(&pfflows.Header)
					a.events[key] = append(a.events[key], f)
				}
			}
		case <-ticker.C:
			if len(a.events) == 0 {
				if stats.messages > 0 {
					log.LogDebugf(ctx, "pfflow aggregator: %d messages carried no flows this window", stats.messages)
				}
				stats = newWindowStats()
				continue
			}

			batch := flushBatch{events: a.events, stats: stats, tickedAt: time.Now()}
			a.events = make(map[EventKey][]PfFlow, len(batch.events))
			stats = newWindowStats()

			// Hand the window to the flusher. The channel holds one window, so
			// this only blocks when the flusher is already a full window behind;
			// then ingestion pauses (bounded memory) and the delay shows up as
			// consumer lag rather than silent loss.
			select {
			case a.flushChan <- batch:
			default:
				log.LogWarnf(ctx, "pfflow aggregator: flusher is one window (%s) behind, pausing ingestion until the previous flush completes", a.timeout)
				a.flushChan <- batch
			}
		case <-a.stop:
			break loop
		}
	}
}
