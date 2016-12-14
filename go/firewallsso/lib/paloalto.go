package libfirewallsso

import (
	"context"
)

type PaloAlto struct {
	FirewallSSO
	Password string `json:"password"`
	Port     string `json:"port"`
}

func (fw *PaloAlto) Start(ctx context.Context, info map[string]string, timeout int) bool {
	return true
}

func (fw *PaloAlto) Stop(ctx context.Context, info map[string]string) bool {
	return false
}
