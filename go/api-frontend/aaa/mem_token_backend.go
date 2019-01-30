package aaa

import (
	"time"

	cache "github.com/patrickmn/go-cache"
)

type MemTokenBackend struct {
	store *cache.Cache
}

func NewMemTokenBackend(expiration time.Duration) *MemTokenBackend {
	return &MemTokenBackend{
		store: cache.New(expiration, 10*time.Minute),
	}
}

func (mtb *MemTokenBackend) TokenIsValid(token string) bool {
	_, found := mtb.store.Get(token)
	return found
}

func (mtb *MemTokenBackend) TokenInfoForToken(token string) *TokenInfo {
	o, found := mtb.store.Get(token)
	if found {
		return o.(*TokenInfo)
	} else {
		return nil
	}
}

func (mtb *MemTokenBackend) TenantIdForToken(token string) int {
	if ti := mtb.TokenInfoForToken(token); ti != nil {
		return ti.TenantId
	} else {
		return AccessNoTenants
	}
}

func (mtb *MemTokenBackend) AdminRolesForToken(token string) map[string]bool {
	if ti := mtb.TokenInfoForToken(token); ti != nil {
		return ti.AdminRoles()
	} else {
		return make(map[string]bool)
	}
}

func (mtb *MemTokenBackend) StoreTokenInfo(token string, ti *TokenInfo) error {
	mtb.store.SetDefault(token, ti)
	return nil
}
