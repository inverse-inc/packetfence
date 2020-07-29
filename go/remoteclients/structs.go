package remoteclients

import "net"

type Peer struct {
	WireguardIP      net.IP   `json:"wireguard_ip"`
	WireguardNetmask int      `json:"wireguard_netmask"`
	PublicKey        string   `json:"public_key"`
	AllowedPeers     []string `json:"allowed_peers,omitempty"`
}
