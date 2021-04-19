package remoteclients

import "net"

const (
	AUTH_TIMESTAMP_START = 0
	AUTH_TIMESTAMP_END   = 8
	AUTH_RAND_START      = AUTH_TIMESTAMP_END
	AUTH_RAND_END        = 40
	AUTH_PUB_START       = AUTH_RAND_END
	AUTH_PUB_END         = 72
)

const PRIVATE_EVENTS_SUFFIX = "priv-"

type Event struct {
	Type string                 `json:"type"`
	Data map[string]interface{} `json:"data"`
}

type Peer struct {
	WireguardIP             net.IP   `json:"wireguard_ip"`
	WireguardNetmask        int      `json:"wireguard_netmask"`
	PublicKey               string   `json:"public_key,omitempty"`
	AllowedPeers            []string `json:"allowed_peers,omitempty"`
	NamesToResolve          []string `json:"names_to_resolve"`
	DomainsToResolve        []string `json:"domains_to_resolve"`
	ACLs                    []string `json:"acls"`
	Routes                  []string `json:"routes"`
	IsGateway               bool     `json:"is_gateway"`
	Hostname                string   `json:"hostname"`
	STUNServer              string   `json:"stun_server"`
	InternalDomainToResolve string   `json:"internal_domain_to_resolve"`
	RBACIPFiltering         bool     `json:"rbac_ip_filtering"`
}
