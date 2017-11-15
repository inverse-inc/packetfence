package aaa

type TokenBackend interface {
	AdminRolesForToken(token string) []string
	StoreTokenInfo(token string, ti *TokenInfo) error
	TokenIsValid(token string) bool
}

type TokenInfo struct {
	adminRoles []string
	tenantId   int
}
