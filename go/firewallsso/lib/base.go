package libfirewallsso

import (
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type FirewallSSOInt interface {
	Start(info map[string]string, timeout int) bool
	Stop(info map[string]string) bool
}

type FirewallSSO struct {
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::Firewall_SSO"`
	PfconfigHashNS string `val:"-"`
	pfconfigdriver.TypedConfig
	Networks     []string `json:"networks"`
	CacheUpdates string   `json:"cache_updates"`
}

type RoleBasedFirewallSSO struct {
	Roles []string `json:"categories"`
}

func (rbf *RoleBasedFirewallSSO) MatchesRole(userRole string) bool {
	for _, role := range rbf.Roles {
		if userRole == role {
			return true
		}
	}
	return false
}
