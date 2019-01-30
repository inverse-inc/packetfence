package aaa

import (
	"context"
	"sync"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

type AuthenticationBackend interface {
	Authenticate(ctx context.Context, username, password string) (bool, *TokenInfo, error)
}

type MemAuthenticationBackend struct {
	validUsers map[string]string
	// The admin roles that will apply to *ALL* users of this backend
	adminRolesGroups map[string]bool
	sem              *sync.RWMutex
}

func NewMemAuthenticationBackend(validUsers map[string]string, adminRolesGroups map[string]bool) *MemAuthenticationBackend {
	pfconfigdriver.PfconfigPool.AddStruct(context.Background(), &pfconfigdriver.Config.AdminRoles)

	mab := &MemAuthenticationBackend{
		validUsers:       validUsers,
		adminRolesGroups: adminRolesGroups,
		sem:              &sync.RWMutex{},
	}

	return mab
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

func (mab *MemAuthenticationBackend) Authenticate(ctx context.Context, username, password string) (bool, *TokenInfo, error) {
	mab.sem.RLock()
	defer mab.sem.RUnlock()

	if storedPass, found := mab.validUsers[username]; found {
		if password == storedPass {
			return true, &TokenInfo{
				AdminRolesGroups: mab.adminRolesGroups,
				TenantId:         AccessAllTenants,
			}, nil
		} else {
			return false, nil, nil
		}
	} else {
		return false, nil, nil
	}
}
