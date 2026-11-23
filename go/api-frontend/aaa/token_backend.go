package aaa

import (
	"context"
	"crypto/sha256"
	"fmt"
	"time"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type TokenBackend interface {
	AdminActionsForToken(ctx context.Context, token string) map[string]bool
	TokenInfoForToken(token string) (*TokenInfo, time.Time)
	StoreTokenInfo(token string, ti *TokenInfo) error
	TokenIsValid(token string) bool
	TouchTokenInfo(token string)
	Type() string
}

const tokenPrefix = "api-frontend-session:"

func tokenKey(tb TokenBackend, token string) string {
	return tokenPrefix + fmt.Sprintf("%x", sha256.Sum256([]byte(token)))
}

func AdminActionsForToken(ctx context.Context, tb TokenBackend, token string) map[string]bool {
	if ti, _ := tb.TokenInfoForToken(token); ti != nil {
		return ti.AdminActions(ctx)
	}

	return make(map[string]bool)
}

type TokenInfo struct {
	AdminRoles map[string]bool `json:"admin_roles" redis:"admin_roles"`
	Username   string          `json:"username" redis:"username"`
	CreatedAt  time.Time       `json:"created_at" redis:"created_at"`
}

func (ti *TokenInfo) AdminActions(ctx context.Context) map[string]bool {
	roles := make([]string, 0, len(ti.AdminRoles))
	for role := range ti.AdminRoles {
		roles = append(roles, role)
	}
	return ActionsForRoles(ctx, roles)
}

// ActionsForRoles are the actions of admin roles (conf/adminroles.conf), the
// union of the actions of each role. An unknown role has no action.
func ActionsForRoles(ctx context.Context, roles []string) map[string]bool {
	actions := make(map[string]bool)
	adminRoles := pfconfigdriver.GetStruct(ctx, "AdminRoles").(*pfconfigdriver.AdminRoles)

	for _, role := range roles {
		for action := range adminRoles.Element[role].Actions {
			actions[action] = true
		}
	}

	return actions
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
