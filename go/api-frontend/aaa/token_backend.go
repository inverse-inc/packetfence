package aaa

import (
	"time"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type TokenBackend interface {
	AdminActionsForToken(token string) map[string]bool
	TenantIdForToken(token string) int
	TokenInfoForToken(token string) (*TokenInfo, time.Time)
	StoreTokenInfo(token string, ti *TokenInfo) error
	TokenIsValid(token string) bool
	TouchTokenInfo(token string)
}

const (
	AccessAllTenants = 0
	AccessNoTenants  = -1
)

type TokenInfo struct {
	AdminRoles map[string]bool
	Tenant     Tenant
	Username   string
	CreatedAt  time.Time
}

type Tenant struct {
	Name             string `json:"name"`
	PortalDomainName string `json:"portal_domain_name"`
	DomainName       string `json:"domain_name"`
	Id               int    `json:"id"`
}

func (ti *TokenInfo) IsTenantMaster() bool {
	// If we're not in multi-tenant mode
	// Or we're in multi-tenant mode and the current token is for the master tenant (tenant 0)
	if !multipleTenants || (multipleTenants && ti.Tenant.Id == AccessAllTenants) {
		return true
	} else {
		return false
	}
}

func (ti *TokenInfo) AdminActions() map[string]bool {
	adminRolesMap := make(map[string]bool)

	for role, _ := range ti.AdminRoles {
		for role, _ := range pfconfigdriver.Config.AdminRoles.Element[role].Actions {
			adminRolesMap[role] = true
		}
	}

	if ti.IsTenantMaster() {
		adminRolesMap["TENANT_MASTER"] = true
	}

	return adminRolesMap
}
