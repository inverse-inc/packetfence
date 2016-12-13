package libfirewallsso

import ()

type PaloAlto struct {
	FirewallSSO
	Password string `json:"password"`
	Port     string `json:"port"`
}

func (fw *PaloAlto) Start(info map[string]string, timeout int) bool {
	return true
}

func (fw *PaloAlto) Stop(info map[string]string) bool {
	return false
}
