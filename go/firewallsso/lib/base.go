package libfirewallsso

import (
	"fmt"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type FirewallSSOInt interface {
	Start(info map[string]string, timeout int) bool
	Stop(info map[string]string) bool
	GetFirewallSSO() *FirewallSSO
	IsRoleBased() bool
	MatchesRole(info map[string]string) bool
}

type FirewallSSO struct {
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::Firewall_SSO"`
	PfconfigHashNS string `val:"-"`
	RoleBasedFirewallSSO
	pfconfigdriver.TypedConfig
	Networks     []string `json:"networks"`
	CacheUpdates string   `json:"cache_updates"`
}

func (fw *FirewallSSO) GetFirewallSSO() *FirewallSSO {
	return fw
}

func (fw *FirewallSSO) IsRoleBased() bool {
	return true
}

func (fw *FirewallSSO) Start(info map[string]string, timeout int) bool {
	return true
}

func ExecuteStart(fw FirewallSSOInt, info map[string]string, timeout int) bool {
	if fw.IsRoleBased() && !fw.MatchesRole(info) {
		fmt.Printf("Not sending SSO for user device %s since it doesn't match the role \n", info["role"])
		return false
	}
	parentResult := fw.GetFirewallSSO().Start(info, timeout)
	childResult := fw.Start(info, timeout)
	return parentResult && childResult
}

type RoleBasedFirewallSSO struct {
	ShouldMatchRole bool
	Roles           []string `json:"categories"`
}

func (rbf *RoleBasedFirewallSSO) MatchesRole(info map[string]string) bool {
	userRole := info["role"]
	for _, role := range rbf.Roles {
		if userRole == role {
			return true
		}
	}
	return false
}
