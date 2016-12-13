package libfirewallsso

import (
	"fmt"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type FirewallSSOInt interface {
	Start(info map[string]string, timeout int) bool
	GetFirewallSSO() *FirewallSSO
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

func (fw *FirewallSSO) GetFirewallSSO() *FirewallSSO {
	return fw
}

func (fw *FirewallSSO) Start(info map[string]string, timeout int) bool {
	fmt.Println("Hey I'm in FirewallSSO")
	return true
}

func ExecuteStart(fw FirewallSSOInt, info map[string]string, timeout int) bool {
	parentResult := fw.GetFirewallSSO().Start(info, timeout)
	childResult := fw.Start(info, timeout)
	return parentResult && childResult
}

type RoleBasedFirewallSSO struct {
	Roles []string `json:"categories"`
}

func (rbf *RoleBasedFirewallSSO) MatchesRole(info map[string]string) bool {
	userRole := info["role"]
	for _, role := range rbf.Roles {
		if userRole == role {
			return true
		}
	}
	fmt.Printf("Not sending SSO for user device %s since it doesn't match the role \n", userRole)
	return false
}
