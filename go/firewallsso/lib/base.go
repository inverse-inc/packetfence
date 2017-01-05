package libfirewallsso

import (
	"context"
	"fmt"
	log "github.com/inconshreveable/log15"
	"github.com/inverse-inc/packetfence/go/logging"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"net"
)

// Basic interface that all FirewallSSO must implement
type FirewallSSOInt interface {
	init(ctx context.Context) error
	logger(ctx context.Context) log.Logger
	Start(ctx context.Context, info map[string]string, timeout int) bool
	Stop(ctx context.Context, info map[string]string) bool
	GetFirewallSSO(ctx context.Context) *FirewallSSO
	IsRoleBased(ctx context.Context) bool
	MatchesRole(ctx context.Context, info map[string]string) bool
	MatchesNetwork(ctx context.Context, info map[string]string) bool
}

// Basic struct for all firewalls
type FirewallSSO struct {
	PfconfigMethod string `val:"hash_element"`
	PfconfigNS     string `val:"config::Firewall_SSO"`
	PfconfigHashNS string `val:"-"`
	RoleBasedFirewallSSO
	pfconfigdriver.TypedConfig
	Networks     []*FirewallSSONetwork `json:"networks"`
	CacheUpdates string                `json:"cache_updates"`
}

// Builds all networks, meant to be called after the data is loaded into the struct attributes
func (fw *FirewallSSO) init(ctx context.Context) error {
	for _, net := range fw.Networks {
		err := net.init(ctx)
		if err != nil {
			return err
		}
	}
	return nil
}

// Structure representing a network part of a firewall
type FirewallSSONetwork struct {
	Cidr  string
	Ip    net.IP
	IpNet *net.IPNet
}

// Builds Ip and IpNet based on the Cidr in the struct
func (fwn *FirewallSSONetwork) init(ctx context.Context) error {
	var err error
	fwn.Ip, fwn.IpNet, err = net.ParseCIDR(fwn.Cidr)
	return err
}

// Get the base firewall SSO object
// This is used so that all structs including FirewallSSO have access to FirewallSSO via the FirewallSSOInt interface
func (fw *FirewallSSO) GetFirewallSSO(ctx context.Context) *FirewallSSO {
	return fw
}

// Whether or not this firewall is role based.
// Meant to be overriden if necessary by structs including FirewallSSO
func (fw *FirewallSSO) IsRoleBased(ctx context.Context) bool {
	return true
}

// Start method that will be called on every SSO called via ExecuteStart
func (fw *FirewallSSO) Start(ctx context.Context, info map[string]string, timeout int) bool {
	fw.logger(ctx).Debug("Sending SSO start")
	return true
}

// Check if info["ip"] is part of the configured networks if any
// If there isn't any network, all networks are allowed
// Otherwise, if the IP is part of one of the networks, this succeeds, otherwise it fails
func (fw *FirewallSSO) MatchesNetwork(ctx context.Context, info map[string]string) bool {
	if len(fw.Networks) == 0 {
		fw.logger(ctx).Debug("No network defined. Allowing all networks")
		return true
	}
	ip := net.ParseIP(info["ip"])
	for _, net := range fw.Networks {
		if net.IpNet.Contains(ip) {
			fw.logger(ctx).Debug(fmt.Sprintf("%s matches network %s", ip, net.Cidr))
			return true
		}
	}
	fw.logger(ctx).Debug(fmt.Sprintf("%s doesn't match any configured network", ip))
	return false
}

// Struct to be combined with another one when the firewall SSO should only be for certain roles
type RoleBasedFirewallSSO struct {
	Roles []string `json:"categories"`
}

// Is the role in info["role"] part of the roles that are configured for the SSO
func (rbf *RoleBasedFirewallSSO) MatchesRole(ctx context.Context, info map[string]string) bool {
	userRole := info["role"]
	for _, role := range rbf.Roles {
		if userRole == role {
			return true
		}
	}
	return false
}

func (fw *FirewallSSO) logger(ctx context.Context) log.Logger {
	return logging.Logger(ctx, "firewall-id", fw.PfconfigHashNS)
}

// Execute an SSO request on the specified firewall
// Makes sure to call FirewallSSO.Start and to validate the network and role if necessary
func ExecuteStart(ctx context.Context, fw FirewallSSOInt, info map[string]string, timeout int) bool {
	ctx = logging.AddToLogContext(ctx, "ip", info["ip"], "mac", info["mac"])
	if fw.IsRoleBased(ctx) && !fw.MatchesRole(ctx, info) {
		fw.logger(ctx).Info(fmt.Sprintf("Not sending SSO for user device %s since it doesn't match the role", info["role"]))
		return false
	}

	if !fw.MatchesNetwork(ctx, info) {
		fw.logger(ctx).Info(fmt.Sprintf("Not sending SSO for IP %s since it doesn't match any configured network", info["ip"]))
		return false
	}

	parentResult := fw.GetFirewallSSO(ctx).Start(ctx, info, timeout)
	childResult := fw.Start(ctx, info, timeout)
	return parentResult && childResult
}
