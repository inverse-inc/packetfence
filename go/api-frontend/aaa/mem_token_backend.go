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

func (mtb *MemTokenBackend) AdminRolesForToken(token string) []string {
	o, found := mtb.store.Get(token)
	if found {
		return o.([]string)
	} else {
		return []string{}
	}
}

func (mtb *MemTokenBackend) StoreAdminRolesForToken(token string, roles []string) error {
	mtb.store.SetDefault(token, roles)
	return nil
}
