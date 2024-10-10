package common

import (
	"context"
	"encoding/json"

	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

type Node struct {
	Autoreg            string      `json:"autoreg,omitempty"`
	BandwidthBalance   string      `json:"bandwidth_balance,omitempty"`
	BypassRoleID       string      `json:"bypass_role_id,omitempty"`
	BypassVLAN         string      `json:"bypass_vlan,omitempty"`
	CategoryID         json.Number `json:"category_id,omitempty"`
	Computername       string      `json:"computername,omitempty"`
	DetectDate         string      `json:"detect_date,omitempty"`
	DeviceClass        string      `json:"device_class,omitempty"`
	DeviceManufacturer string      `json:"device_manufacturer,omitempty"`
	DeviceScore        string      `json:"device_score,omitempty"`
	DeviceType         string      `json:"device_type,omitempty"`
	DeviceVersion      string      `json:"device_version,omitempty"`
	Dhcp6Enterprise    string      `json:"dhcp6_enterprise,omitempty"`
	Dhcp6Fingerprint   string      `json:"dhcp6_fingerprint,omitempty"`
	DhcpFingerprint    string      `json:"dhcp_fingerprint,omitempty"`
	DhcpVendor         string      `json:"dhcp_vendor,omitempty"`
	LastARP            string      `json:"last_arp,omitempty"`
	LastDHCP           string      `json:"last_dhcp,omitempty"`
	LastSeen           string      `json:"last_seen,omitempty"`
	MAC                string      `json:"mac,omitempty"`
	MachineAccount     string      `json:"machine_account,omitempty"`
	Notes              string      `json:"notes,omitempty"`
	PID                string      `json:"pid,omitempty"`
	Regdate            string      `json:"regdate,omitempty"`
	Sessionid          string      `json:"sessionid,omitempty"`
	Status             string      `json:"status,omitempty"`
	TimeBalance        string      `json:"time_balance,omitempty"`
	Unregdate          string      `json:"unregdate,omitempty"`
	UserAgent          string      `json:"user_agent,omitempty"`
	VoIP               string      `json:"voip,omitempty"`
}

type NodeInfo struct {
	Node
	BypassRole            string `json:"bypass_role,omitempty"`
	Category              string `json:"category,omitempty"`
	LastConnectionSubType string `json:"last_connection_sub_type,omitempty"`
	LastConnectionType    string `json:"last_connection_type,omitempty"`
	LastDot1xUsername     string `json:"last_dot1x_username,omitempty"`
	LastEndTime           string `json:"last_end_time,omitempty"`
	LastIfDesc            string `json:"last_ifDesc,omitempty"`
	LastPort              string `json:"last_port,omitempty"`
	LastRole              string `json:"last_role,omitempty"`
	LastSSID              string `json:"last_ssid,omitempty"`
	LastStartTime         string `json:"last_start_time,omitempty"`
	LastStartTimestamp    string `json:"last_start_timestamp,omitempty"`
	LastSwitch            string `json:"last_switch,omitempty"`
	LastSwitchMAC         string `json:"last_switch_mac,omitempty"`
	LastVLAN              string `json:"last_vlan,omitempty"`
	Realm                 string `json:"realm,omitempty"`
	StrippedUserName      string `json:"stripped_user_name,omitempty"`
}

func (n *Node) CategoryID_int() int {
	i, _ := n.CategoryID.Int64()
	return int(i)
}

func FetchNodeInfo(ctx context.Context, mac string) (NodeInfo, unifiedapiclient.UnifiedAPIError) {
	client := unifiedapiclient.NewFromConfig(ctx)

	resp := struct {
		Item NodeInfo
	}{}
	err := client.Call(ctx, "GET", "/api/v1/node/"+mac, &resp)
	return resp.Item, err
}

func (n *Node) Upsert(ctx context.Context) error {
	client := unifiedapiclient.NewFromConfig(ctx)

	err := client.CallWithBody(ctx, "PATCH", "/api/v1/node/"+n.MAC, n, &unifiedapiclient.DummyReply{})
	if err == nil {
		return nil
	}

	log.LoggerWContext(ctx).Info("Got an error while updating node " + n.MAC + ". Will try to create it instead. Error: " + err.Error())

	err = client.CallWithBody(ctx, "POST", "/api/v1/nodes", n, &unifiedapiclient.DummyReply{})
	if err != nil {
		log.LoggerWContext(ctx).Error("Unable to upsert node " + n.MAC + ".Error: " + err.Error())
	}

	return err
}
