package aaa

import (
	"time"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type TokenBackend interface {
	AdminActionsForToken(token string) map[string]bool
	TokenInfoForToken(token string) (*TokenInfo, time.Time)
	StoreTokenInfo(token string, ti *TokenInfo) error
	TokenIsValid(token string) bool
	TouchTokenInfo(token string)
}

const tokenPrefix = "api-frontend-session:"

func tokenKey(tb TokenBackend, token string) string {
	return tokenPrefix + token
}

func AdminActionsForToken(tb TokenBackend, token string) map[string]bool {
	if ti, _ := tb.TokenInfoForToken(token); ti != nil {
		return ti.AdminActions()
	}

	return make(map[string]bool)
}

type TokenInfo struct {
	AdminRoles map[string]bool `json:"admin_roles" redis:"admin_roles"`
	Username   string          `json:"username" redis:"username"`
	CreatedAt  time.Time       `json:"created_at" redis:"created_at"`
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

func ValidTokenExpiration(ti *TokenInfo, expiration time.Time, max time.Duration) (*TokenInfo, time.Time) {
	if time.Now().Sub(ti.CreatedAt) > max {
		// Token has reached max expiration
		return nil, time.Unix(0, 0)
	}

	if expiration.After(ti.CreatedAt.Add(max)) {
		expiration = ti.CreatedAt.Add(max)
	}

	return ti, expiration
}

func MakeTokenBackend(args []string) TokenBackend {
	if len(args) == 0 {
		return NewMemTokenBackend(
			time.Duration(pfconfigdriver.Config.PfConf.Advanced.ApiInactivityTimeout)*time.Second,
			time.Duration(pfconfigdriver.Config.PfConf.Advanced.ApiMaxExpiration)*time.Second,
			args,
		)
	}

	switch args[0] {
	case "db":
		return NewDbTokenBackend(
			time.Duration(pfconfigdriver.Config.PfConf.Advanced.ApiInactivityTimeout)*time.Second,
			time.Duration(pfconfigdriver.Config.PfConf.Advanced.ApiMaxExpiration)*time.Second,
			args[1:],
		)
	case "redis":
		return NewRedisTokenBackend(
			time.Duration(pfconfigdriver.Config.PfConf.Advanced.ApiInactivityTimeout)*time.Second,
			time.Duration(pfconfigdriver.Config.PfConf.Advanced.ApiMaxExpiration)*time.Second,
			args[1:],
		)
	default:
		return NewMemTokenBackend(
			time.Duration(pfconfigdriver.Config.PfConf.Advanced.ApiInactivityTimeout)*time.Second,
			time.Duration(pfconfigdriver.Config.PfConf.Advanced.ApiMaxExpiration)*time.Second,
			args[1:],
		)
	}

}
