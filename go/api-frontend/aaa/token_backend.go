package aaa

type TokenBackend interface {
	AdminRolesForToken(token string) []string
	StoreAdminRolesForToken(token string, roles []string) error
}
