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

func (mtb *MemTokenBackend) tokenInfoForToken(token string) *TokenInfo {
	o, found := mtb.store.Get(token)
	if found {
		return o.(*TokenInfo)
	} else {
		return nil
	}
}

func (mtb *MemTokenBackend) TenantIdForToken(token string) int {
	if ti := mtb.tokenInfoForToken(token); ti != nil {
		return ti.tenantId
	} else {
		return -1
	}
}

func (mtb *MemTokenBackend) AdminRolesForToken(token string) []string {
	if ti := mtb.tokenInfoForToken(token); ti != nil {
		return ti.adminRoles
	} else {
		return []string{}
	}
}

func (mtb *MemTokenBackend) StoreTokenInfo(token string, ti *TokenInfo) error {
	mtb.store.SetDefault(token, ti)
	return nil
}
