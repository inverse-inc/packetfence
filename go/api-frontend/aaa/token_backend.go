package aaa

type TokenBackend interface {
	AdminRolesForToken(token string) map[string]bool
	TenantIdForToken(token string) int
	TokenInfoForToken(token string) *TokenInfo
	StoreTokenInfo(token string, ti *TokenInfo) error
	TokenIsValid(token string) bool
}

type TokenInfo struct {
	AdminRoles map[string]bool
	TenantId   int
}
