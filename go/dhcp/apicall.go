package main

import (
	"bytes"
	"encoding/json"
	"net"
	"net/http"
)

// Query prepare the json payload
type Query struct {
	Method string   `json:"method"`
	ID     string   `json:"id"`
	Params []string `json:"params"`
}

// NodeInfo struct to convert json answer in struct
type NodeInfo struct {
	ID     string            `json:"id"`
	Result []NodeInfoDetails `json:"result"`
}

// NodeInfoDetails struct describe node attributes
type NodeInfoDetails struct {
	Autoreg               string `json:"autoreg"`
	LastPort              string `json:"last_port"`
	DeviceClass           string `json:"device_class"`
	BandwidthBalance      string `json:"bandwidth_balance"`
	BypassRole            string `json:"bypass_role"`
	DeviceType            string `json:"device_type"`
	PID                   string `json:"pid"`
	DHCP6Enterprise       string `json:"dhcp6_enterprise"`
	DHCP6Fingerprint      string `json:"dhcp6_fingerprint"`
	Category              string `json:"category"`
	MAC                   string `json:"mac"`
	Lastskip              string `json:"lastskip"`
	LastDHCP              string `json:"last_dhcp"`
	UserAgent             string `json:"user_agent"`
	LastVlan              string `json:"last_vlan"`
	LastConnectionSubType string `json:"last_connection_sub_type"`
	BypassRoleID          string `json:"bypass_role_id"`
	LastRole              string `json:"last_role"`
	LastSwitch            string `json:"last_switch"`
	Unregdate             string `json:"unregdate"`
	DHCPVendor            string `json:"dhcp_vendor"`
	DeviceVersion         string `json:"device_version"`
	Status                string `json:"status"`
	BypassVlan            string `json:"bypass_vlan"`
	Regdate               string `json:"regdate"`
	LastDot1xUsername     string `json:"last_dot1x_username"`
	CategoryID            string `json:"category_id"`
	LastConnectionType    string `json:"last_connection_type"`
	MachineAccount        string `json:"machine_account"`
	LastSSID              string `json:"last_ssid"`
	Realm                 string `json:"realm"`
	DeviceScore           string `json:"device_score"`
	LastARP               string `json:"last_arp"`
	UnregdateTimestamp    string `json:"unregdate_timestamp"`
	LastStartTimestamp    string `json:"last_start_timestamp"`
	StrippedUserName      string `json:"stripped_user_name"`
	VoIP                  string `json:"voip"`
	TimeBalance           string `json:"time_balance"`
	Notes                 string `json:"notes"`
	LastSwitchMAC         string `json:"last_switch_mac"`
	LastStartTime         string `json:"last_start_time"`
	SessionID             string `json:"session_id"`
	RegdateTimestamp      string `json:"regdate_timestamp"`
}

//NodeInformation do a call to the PacketFence web api in order to retrive node information
func NodeInformation(target net.HardwareAddr) (r NodeInfo) {

	q := Query{
		Method: "node_information",
		ID:     "1",
		Params: []string{"mac", target.String()},
	}

	b := bytes.NewBuffer([]byte{})
	json.NewEncoder(b).Encode(q)

	res, err := http.Post("http://127.0.0.1:9090", "application/jsonrequest", b)

	if err != nil {
		return r
	}

	json.NewDecoder(res.Body).Decode(&r)
	return r
}
