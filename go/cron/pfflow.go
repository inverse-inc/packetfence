package maint

import (
	"net/netip"
	"time"
)

//easyjson:json
type PfFlowHeader struct {
	AgentAddr      netip.Addr `json:"agent_addr"`
	Timestamp      uint64     `json:"timestamp"`
	FlowSeq        uint32     `json:"flow_seq"`
	DomainID       uint32     `json:"domain_id"`
	SubAgentID     uint32     `json:"sub_agent_id"`
	SysUptime      uint32     `json:"sys_uptime"`
	FlowType       uint16     `json:"flow_type"`
	SampleInterval uint16     `json:"sample_interval"`
	EngineType     uint8      `json:"engine_type"`
	EngineId       uint8      `json:"engine_id"`
}

//easyjson:json
type PfFlows struct {
	Header PfFlowHeader `json:"header"`
	Flows  *[]PfFlow    `json:"flows"`
}

//easyjson:json
type PfFlow struct {
	SrcIp           netip.Addr `json:"src_ip"`
	DstIp           netip.Addr `json:"dst_ip"`
	NextAddr        netip.Addr `json:"next_addr"`
	SrcMac          string     `json:"src_mac"`
	DstMac          string     `json:"dst_mac"`
	StartTime       int64      `json:"start_time"`
	EndTime         int64      `json:"end_time"`
	ByteCount       uint32     `json:"byte_count"`
	First           uint32     `json:"first"`
	Last            uint32     `json:"last"`
	SrcPort         uint16     `json:"src_port"`
	DstPort         uint16     `json:"dst_port"`
	SnmpIndexInput  uint16     `json:"snmp_index_input"`
	SnmpIndexOutput uint16     `json:"snmp_index_output"`
	PacketCount     uint64     `json:"packet_count"`
	SrcAS           uint16     `json:"src_as"`
	DstAS           uint16     `json:"dst_as"`
	TCPFlags        uint8      `json:"tcp_flags"`
	BiFlow          uint8      `json:"biflow"`
	Direction       uint8      `json:"direction"`
	Proto           uint8      `json:"proto"`
	SrcMask         uint8      `json:"src_mask"`
	DstMask         uint8      `json:"dst_mask"`
	ToS             uint8      `json:"tos"`
}

func (f *PfFlow) Key(h *PfFlowHeader) EventKey {
	switch f.BiFlow {
	default:
		return EventKey{
			SrcIp:     f.SrcIp,
			DstIp:     f.DstIp,
			DstPort:   f.DstPort,
			Proto:     f.Proto,
			HasBiFlow: false,
		}
	case 1:
		return EventKey{
			SrcIp:     f.SrcIp,
			DstIp:     f.DstIp,
			DstPort:   f.DstPort,
			Proto:     f.Proto,
			HasBiFlow: true,
		}
	case 2:
		return EventKey{
			DstIp:     f.SrcIp,
			SrcIp:     f.DstIp,
			DstPort:   f.SrcPort,
			Proto:     f.Proto,
			HasBiFlow: true,
		}
	}
}
func (f *PfFlow) Heuristics() {
	if f.BiFlow != 1 && f.BiFlow != 2 && f.Proto == 6 {
		if f.TCPFlags == TCPFlagSYN {
			f.Direction = 2
			return
		}
		if f.DstPort <= 1024 && f.SrcPort >= 10000 {
			f.Direction = 2
			return
		}
		if f.SrcPort <= 1024 && f.DstPort >= 10000 {
			f.Direction = 1
		}
	}
}

func (f *PfFlow) SessionKey() AggregatorSession {
	if f.BiFlow == 2 {
		return AggregatorSession{Port: f.DstPort}
	}

	return AggregatorSession{Port: f.SrcPort}
}

func (f *PfFlow) NetworkEventDirection() NetworkEventDirection {
	switch f.BiFlow {
	default:
		return NetworkEventDirection("")
	case 1:
		return NetworkEventDirectionInBound
	case 2:
		return NetworkEventDirectionOutBound
	}
}

func (f *PfFlow) CalculatedDstPort() int {
	if f.BiFlow == 2 {
		return int(f.SrcPort)
	}

	return int(f.DstPort)
}

func (f *PfFlow) CalculatedSrcIp() netip.Addr {
	if f.BiFlow == 2 {
		return f.DstIp
	}

	return f.SrcIp
}

func (f *PfFlow) CalculatedDstIp() netip.Addr {
	if f.BiFlow == 2 {
		return f.SrcIp
	}

	return f.DstIp
}

func (f *PfFlow) ToNetworkEvent() *NetworkEvent {
	if f.DstMac == "00:00:00:00:00:00" && f.SrcMac == "00:00:00:00:00:00" {
		return nil
	}

	ipProto, err := ProtoToIpProtocol(int(f.Proto))
	if err != nil {
		return nil
	}

	return &NetworkEvent{
		EventType:           NetworkEventTypeSuccessful,
		SourceIp:            f.CalculatedSrcIp(),
		DestIp:              f.CalculatedDstIp(),
		DestPort:            f.CalculatedDstPort(),
		IpProtocol:          ipProto,
		IpVersion:           IpVersionIpv4,
		EnforcementState:    EnforcementStateEnforcing,
		Count:               1,
		StartTime:           uint64(time.Now().Unix()),
		Direction:           f.NetworkEventDirection(),
		DestInventoryitem:   f.DestInventoryitem(),
		SourceInventoryItem: f.SourceInventoryitem(),
		ReportingEntity:     &GlobalReportingEntity,
	}
}

func (f *PfFlow) DestInventoryitem() *InventoryItem {
	if f.BiFlow == 2 {
		return macToInventoryitem(f.SrcMac)
	}

	return macToInventoryitem(f.DstMac)
}

func (f *PfFlow) SourceInventoryitem() *InventoryItem {
	if f.BiFlow == 2 {
		return macToInventoryitem(f.DstMac)
	}

	return macToInventoryitem(f.SrcMac)
}

func macToInventoryitem(mac string) *InventoryItem {
	if mac == "" || mac == "00:00:00:00:00:00" {
		return nil
	}

	return &InventoryItem{
		ItemType:    "asset",
		ExternalIDS: []string{mac},
	}
}
