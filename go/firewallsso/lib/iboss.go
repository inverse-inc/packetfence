package libfirewallsso

import (
	"fmt"
)

type Iboss struct {
	FirewallSSO
	RoleBasedFirewallSSO
	NacName  string `json:"nac_name"`
	Password string `json:"password"`
	Port     string `json:"port"`
}

func (fw *Iboss) Start(info map[string]string, timeout int) bool {
	if fw.RoleBasedFirewallSSO.MatchesRole(info["role"]) {
		fmt.Printf("HTTP SSO BIMMMM %s->%s \n", info["ip"], info["username"])
		return true
	} else {
		fmt.Printf("Not sending SSO for user %s on device %s since it doesn't match the role \n", info["username"], info["role"])
		return false
	}
}

func (fw *Iboss) Stop(info map[string]string) bool {
	return false
}
