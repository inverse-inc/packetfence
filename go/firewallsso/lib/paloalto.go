package libfirewallsso

import (
	"fmt"
)

type PaloAlto struct {
	FirewallSSO
	RoleBasedFirewallSSO
	Password string `json:"password"`
	Port     string `json:"port"`
}

func (fw *PaloAlto) Start(info map[string]string, timeout int) bool {
	if fw.RoleBasedFirewallSSO.MatchesRole(info) {
		fmt.Printf("RADIUS SSO BIMMMM %s->%s \n", info["ip"], info["username"])
		return true
	}
	return false
}

func (fw *PaloAlto) Stop(info map[string]string) bool {
	return false
}
