package aaa

import "github.com/inverse-inc/packetfence/go/pfconfigdriver"

type TokenBackend interface {
	AdminActionsForToken(token string) map[string]bool
	TenantIdForToken(token string) int
	TokenInfoForToken(token string) *TokenInfo
	StoreTokenInfo(token string, ti *TokenInfo) error
	TokenIsValid(token string) bool
}

const (
	AccessAllTenants = 0
	AccessNoTenants  = -1
)

type TokenInfo struct {
	AdminRoles map[string]bool
	TenantId   int
	Username   string
}

func (ti *TokenInfo) AdminActions() map[string]bool {
	adminRolesMap := make(map[string]bool)

	for role, _ := range ti.AdminRoles {
		for role, _ := range pfconfigdriver.Config.AdminRoles.Element[role].Actions {
			adminRolesMap[role] = true
		}
	}

	return adminRolesMap
}
