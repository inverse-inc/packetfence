package maint

import (
	"cmp"
	"context"
	"database/sql"
	"fmt"
	"math"
	"net/netip"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/db"
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
}

func emptyMac(mac string) bool {
	return mac == "00:00:00:00:00:00" || mac == ""
}

func updateMacs(ctx context.Context, f *PfFlow, stmt *sql.Stmt) {
	if !emptyMac(f.SrcMac) && !emptyMac(f.DstMac) {
		return
	}

	var srcMac, dstMac string
	err := stmt.QueryRowContext(ctx, f.SrcIp.String(), f.DstIp.String()).Scan(&srcMac, &dstMac)
	if err != nil {
		log.LogErrorf(ctx, "updateMacs Database Error: %s", err.Error())
	}

	if emptyMac(f.SrcMac) {
		f.SrcMac = srcMac
	}

	if emptyMac(f.DstMac) {
		f.DstMac = dstMac
	}
}

const updateMacsSql = `
SELECT
	COALESCE((SELECT mac FROM ip4log WHERE ip = ?), "00:00:00:00:00:00") as src_mac,
	COALESCE((SELECT mac FROM ip4log WHERE ip = ?), "00:00:00:00:00:00") as dst_mac;
`

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
	ctx := context.Background()
	ticker := time.NewTicker(a.timeout)
	stmt, err := new(sql.Stmt), error(nil)
	//	if a.db != nil {
	stmt, err = a.db.PrepareContext(ctx, updateMacsSql)
	if err != nil {
		log.LogErrorf(ctx, "handleEvents Database Error: %s %s", updateMacsSql, err.Error())
		stmt = nil
	} else {
		defer stmt.Close()
	}
	//	}

loop:
	for {
		select {
		case pfflowsArray := <-ChanPfFlow:
			for _, pfflows := range pfflowsArray {
				log.LogInfof(ctx, "Received %d flows of FlowType %s", len(*pfflows.Flows), flowType(pfflows.Header.FlowType))
				if err := db.MarkSwitchAsSeen(a.db, pfflows.Header.AgentAddr.String()); err != nil {
					log.LogErrorf(ctx, "handleEvents: failed to mark switch %s as seen: %s", pfflows.Header.AgentAddr.String(), err.Error())
				}
				for _, f := range *pfflows.Flows {
					if stmt != nil {
						updateMacs(ctx, &f, stmt)
					}

					key := f.Key(&pfflows.Header)
					val := a.events[key]
					if a.Heuristics {
						f.Heuristics()
					}

					a.events[key] = append(val, f)
				}
			}
		case <-ticker.C:
			networkEvents := []*NetworkEvent{}
			for _, events := range a.events {
				startTime := int64(math.MaxInt64)
				endTime := int64(0)
				connectionCount := uint64(0)
				var networkEvent *NetworkEvent
				for _, e := range events {
					networkEvent = e.ToNetworkEvent()
					if networkEvent != nil {
						break
					}
				}

				if networkEvent == nil {
					continue
				}

				ports := map[AggregatorSession]struct{}{}
				for _, e := range events {
					startTime = min(startTime, e.StartTime)
					endTime = max(endTime, e.EndTime)
					sessionKey := e.SessionKey()
					if _, ok := ports[sessionKey]; !ok {
						ports[sessionKey] = struct{}{}
						connectionCount += e.ConnectionCount
					}
				}

				networkEvent.Count = cmp.Or(int(connectionCount), len(ports))
				if startTime != 0 {
					networkEvent.StartTime = uint64(startTime)
				}

				if endTime != 0 {
					networkEvent.EndTime = uint64(endTime)
				}

				if networkEvent.EndTime == 0 {
					networkEvent.EndTime = networkEvent.StartTime
				}

				networkEvents = append(networkEvents, networkEvent)
			}

			for _, e := range networkEvents {
				e.UpdateEnforcementInfo(ctx, a.db)
			}

			if len(networkEvents) > 0 && a.networkEventChan != nil {
				a.networkEventChan <- networkEvents
			}

			clear(a.events)
		case <-a.stop:
			break loop
		}
	}
}
