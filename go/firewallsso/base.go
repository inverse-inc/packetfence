package firewallsso

import (
	"context"
	"fmt"
	"github.com/fingerbank/processor/log"
	"github.com/fingerbank/processor/sharedutils"
	log15 "github.com/inconshreveable/log15"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"net"
	"strconv"
	"time"
)

// Basic interface that all FirewallSSO must implement
type FirewallSSOInt interface {
	init(ctx context.Context) error
	logger(ctx context.Context) log15.Logger
	getSourceIp(ctx context.Context) net.IP
	Start(ctx context.Context, info map[string]string, timeout int) bool
	Stop(ctx context.Context, info map[string]string) bool
	GetFirewallSSO(ctx context.Context) *FirewallSSO
	MatchesRole(ctx context.Context, info map[string]string) bool
	MatchesNetwork(ctx context.Context, info map[string]string) bool
	GetLoadedAt() time.Time
	SetLoadedAt(time.Time)
}

// Basic struct for all firewalls
type FirewallSSO struct {
	pfconfigdriver.StructConfig
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

func (fw *FirewallSSO) InfoToTemplateCtx(ctx context.Context, info map[string]string, timeout int) map[string]string {
	templateCtx := make(map[string]string)
	for k, v := range info {
		templateCtx[sharedutils.UcFirst(k)] = v
	}

	templateCtx["Timeout"] = strconv.Itoa(timeout)

	return templateCtx
}

// Start method that will be called on every SSO called via ExecuteStart
func (fw *FirewallSSO) Start(ctx context.Context, info map[string]string, timeout int) bool {
	fw.logger(ctx).Debug("Sending SSO start")
	return true
}

// Stop method that will be called on every SSO called via ExecuteStop
func (fw *FirewallSSO) Stop(ctx context.Context, info map[string]string) bool {
	fw.logger(ctx).Debug("Sending SSO stop")
	return true
}

func (fw *FirewallSSO) getSourceIp(ctx context.Context) net.IP {
	managementNetwork := &pfconfigdriver.Config.Interfaces.ManagementNetwork
	pfconfigdriver.FetchDecodeSocketCache(ctx, managementNetwork)

	if managementNetwork.Vip != "" {
		return net.ParseIP(managementNetwork.Vip)
	} else {
		return net.ParseIP(managementNetwork.Ip)
	}
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

	if ip == nil {
		fw.logger(ctx).Error(fmt.Sprintf("%s isn't a valid IP address. Cannot validate the network it belongs to.", ip))
		return false
	}

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
	log.LoggerWContext(ctx).Debug(fmt.Sprintf("Checking if role %s matches %s", userRole, rbf.Roles))
	for _, role := range rbf.Roles {
		if userRole == role {
			return true
		}
	}
	return false
}

// Get the logger for a firewall
func (fw *FirewallSSO) logger(ctx context.Context) log15.Logger {
	ctx = log.AddToLogContext(ctx, "firewall-id", fw.PfconfigHashNS)
	return log.LoggerWContext(ctx)
}

// Execute an SSO Start request on the specified firewall
// Makes sure to call FirewallSSO.Start and to validate the network and role if necessary
func ExecuteStart(ctx context.Context, fw FirewallSSOInt, info map[string]string, timeout int) bool {
	ctx = log.AddToLogContext(ctx, "ip", info["ip"], "mac", info["mac"])
	if !fw.MatchesRole(ctx, info) {
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

// Execute an SSO Stop request on the specified firewall
// Makes sure to call FirewallSSO.Start and to validate the network if necessary
func ExecuteStop(ctx context.Context, fw FirewallSSOInt, info map[string]string, timeout int) bool {
	ctx = log.AddToLogContext(ctx, "ip", info["ip"], "mac", info["mac"])

	if !fw.MatchesNetwork(ctx, info) {
		fw.logger(ctx).Info(fmt.Sprintf("Not sending SSO for IP %s since it doesn't match any configured network", info["ip"]))
		return false
	}

	parentResult := fw.GetFirewallSSO(ctx).Stop(ctx, info)
	childResult := fw.Stop(ctx, info)
	return parentResult && childResult
}
