package aaa

import (
	"errors"
	"sync"
)

type AuthenticationBackend interface {
	Authenticate(username, password string) (bool, *TokenInfo, error)
}

type MemAuthenticationBackend struct {
	validUsers map[string]string
	// The admin roles that will apply to *ALL* users of this backend
	adminRoles map[string]bool
	sem        *sync.RWMutex
}

func NewMemAuthenticationBackend(validUsers map[string]string, adminRoles []string) *MemAuthenticationBackend {
	adminRolesMap := make(map[string]bool)
	for _, r := range adminRoles {
		adminRolesMap[r] = true
	}

	return &MemAuthenticationBackend{
		validUsers: validUsers,
		adminRoles: adminRolesMap,
		sem:        &sync.RWMutex{},
	}
}

func (mab *MemAuthenticationBackend) SetUser(username, password string) {
	mab.sem.Lock()
	defer mab.sem.Unlock()
	mab.validUsers[username] = password
}

func (mab *MemAuthenticationBackend) RemoveUser(username, password string) {
	mab.sem.Lock()
	defer mab.sem.Unlock()
	delete(mab.validUsers, username)
}

func (mab *MemAuthenticationBackend) Authenticate(username, password string) (bool, *TokenInfo, error) {
	mab.sem.RLock()
	defer mab.sem.RUnlock()

	if storedPass, found := mab.validUsers[username]; found {
		if password == storedPass {
			return true, &TokenInfo{
				AdminRoles: mab.adminRoles,
				TenantId:   AccessAllTenants,
			}, nil
		} else {
			return false, nil, errors.New("Username/password combination is invalid")
		}
	} else {
		return false, nil, errors.New("Username wasn't found")
	}
}
