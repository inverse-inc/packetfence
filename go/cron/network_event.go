package maint

import (
	"errors"
	"strconv"
	"strings"
	"sync"
	"time"
)

var UUID = ""

var NetworkEventPool = sync.Pool{
	New: func() interface{} {
		return &NetworkEvent{}
	},
}

func GetNetworkEvent() *NetworkEvent {
	return NetworkEventPool.Get().(*NetworkEvent)
}

func PutNetworkEvent(i *NetworkEvent) {
	*i = NetworkEvent{}
	NetworkEventPool.Put(i)
}

//easyjson:json
type NetworkEvent struct {
	Direction           NetworkEventDirection   `json:"direction"`
	EventType           NetworkEventType        `json:"event-type"`
	SourceIp            string                  `json:"source-ip"`
	DestIp              string                  `json:"dest-ip"`
	DestPort            int                     `json:"dest-port"`
	IpProtocol          IpProtocol              `json:"ip-protocol"`
	IpVersion           IpVersion               `json:"ip-version"`
	EnforcementState    EnforcementState        `json:"enforcement-state"`
	EnforcementInfo     *EnforcementInfo        `json:"enforcement-info"`
	NatInfo             *NetworkTranslationInfo `json:"nat-info"`
	SourceProcessInfo   *ProcessInfo            `json:"source-process-info"`
	DestProcessInfo     *ProcessInfo            `json:"dest-process-info"`
	SourceInventoryItem *InventoryItem          `json:"source-inventory-item"`
	DestInventoryitem   *InventoryItem          `json:"dest-inventory-item"`
	SourceUsername      string                  `json:"source-username"`
	DestUsername        string                  `json:"dest-username"`
	DestDomain          string                  `json:"dest-domain"`
	StartTime           uint64                  `json:"start-time"`
	EndTime             uint64                  `json:"end-time"`
	Count               int                     `json:"count"`
	ReportingEntity     *ReportingEntity        `json:"reporting-entity"` //   integration-specific e.g. broker-id, cloud-app
}

var GlobalReportingEntity = ReportingEntity{
	Type: "packetfence",
}

var InvalidEventTypeErr = errors.New("Invalid Proto")

func ProtoToIpProtocol(proto int) (IpProtocol, error) {
	switch proto {
	default:
		return "", InvalidEventTypeErr
	case 6:
		return IpProtocolTcp, nil
	case 17:
		return IpProtocolUdp, nil
	case 1:
		return IpProtocolIcmp, nil

	}
}

func (ne *NetworkEvent) SetReportingEntity(entity_type, uuid string) {
	if ne.ReportingEntity == nil {
		ne.ReportingEntity = &ReportingEntity{
			Type: entity_type,
			UUID: uuid,
		}

		return
	}

	ne.ReportingEntity.Type = entity_type
	ne.ReportingEntity.UUID = uuid
}

func join(sep string, parts ...string) string {
	return strings.Join(parts, sep)
}

func (e *NetworkEvent) ID() string {
	return join(
		":",
		e.SourceIp,
		e.DestIp,
		strconv.FormatUint(uint64(e.DestPort), 10),
		string(e.IpProtocol),
		string(e.IpVersion),
	)
}

func (e *NetworkEvent) Aggregate(m *NetworkEvent) {
	if m.Count > 0 {
		e.Count += m.Count
	} else if m.Count == 0 {
		e.Count++
	}

	e.EndTime = uint64(time.Now().Unix())
}

type ReportingEntity struct {
	UUID string `json:"uuid"`
	Type string `json:"type"`
}

type NetworkEventType string

const (
	NetworkEventTypeSuccessful NetworkEventType = "successful"
	NetworkEventTypeFailed     NetworkEventType = "failed"
	NetworkEventTypeRedirected NetworkEventType = "redirected"
)

type NetworkEventDirection string

const (
	NetworkEventDirectionOutGoing      NetworkEventDirection = "outgoing"
	NetworkEventDirectionInGoing       NetworkEventDirection = "ingoing"
	NetworkEventDirectionBiDirectional NetworkEventDirection = "bi-directional"
)

type IpProtocol string

const (
	IpProtocolTcp  IpProtocol = "tcp"
	IpProtocolUdp  IpProtocol = "udp"
	IpProtocolIcmp IpProtocol = "icmp"
)

type IpVersion string

const (
	IpVersionIpv4 IpVersion = "ipv4"
	IpVersionIpV6 IpVersion = "ipv6"
)

type EnforcementState string

const (
	EnforcementStateRevealOnly EnforcementState = "reveal-only"
	EnforcementStateMonitoring EnforcementState = "monitoring"
	EnforcementStateEnforcing  EnforcementState = "enforcing"
)

type EnforcementInfo struct {
	RuleID              string             `json:"rule-id"`
	Verdict             EnforcementVerdict `json:"verdict"`
	PolicyRevision      uint64             `json:"policy-revision"`
	DcInventoryRevision uint64             `json:"dc-inventory-revision"`
}

type EnforcementVerdict string

const (
	EnforcementVerdictAllow EnforcementVerdict = "allow"
	EnforcementVerdictAlert EnforcementVerdict = "alert"
	EnforcementVerdictBlock EnforcementVerdict = "block"
)

type NetworkTranslationInfo struct {
	SourceIp string                 `json:"source-ip"`
	DestIp   string                 `json:"dest-ip"`
	Destport int                    `json:"dest-port"`
	Type     NetworkTranslationType `json:"type"`
}

type NetworkTranslationType string

const (
	NetworkTranslationTypeSnat        NetworkTranslationType = "snat"
	NetworkTranslationTypeDnat        NetworkTranslationType = "dnat"
	NetworkTranslationTypeSnatAndDnat NetworkTranslationType = "snat_and_dnat"
)

type ProcessInfo struct {
	ProcessName string   `json:"process-name"`
	ImagePath   string   `json:"image-path"`
	CmdLine     []string `json:"cmdline"`
}

type InventoryItem struct {
	ItemType           string                 `json:"item-type"`           //     Optional e.g. asset. If not set can assumed to be an asset
	ItemID             string                 `json:"item-id"`             // reference to Centra inventory item
	MetadataAttributes map[string]interface{} `json:"metadata-attributes"` // container for item-specific attributes
}
