package libfirewallsso

import ()

type Iboss struct {
	FirewallSSO
	NacName  string `json:"nac_name"`
	Password string `json:"password"`
	Port     string `json:"port"`
}

func (fw *Iboss) Start(info map[string]string, timeout int) bool {
	return true
}

func (fw *Iboss) Stop(info map[string]string) bool {
	return false
}
