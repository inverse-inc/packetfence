package aaa

type TokenBackend interface {
	AdminRolesForToken(token string) map[string]bool
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
