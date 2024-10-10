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
	adminRoles map[string]bool
	lock       *sync.RWMutex
}

func NewMemAuthenticationBackend(validUsers map[string]string, adminRoles map[string]bool) *MemAuthenticationBackend {
	pfconfigdriver.AddStruct(context.Background(), "AdminRoles", &pfconfigdriver.AdminRoles{})

	mab := &MemAuthenticationBackend{
		validUsers: validUsers,
		adminRoles: adminRoles,
		lock:       &sync.RWMutex{},
	}

	return mab
}

func (mab *MemAuthenticationBackend) SetUser(username, password string) {
	mab.lock.Lock()
	defer mab.lock.Unlock()
	mab.validUsers[username] = password
}

func (mab *MemAuthenticationBackend) RemoveUser(username, password string) {
	mab.lock.Lock()
	defer mab.lock.Unlock()
	delete(mab.validUsers, username)
}

func (mab *MemAuthenticationBackend) Authenticate(ctx context.Context, username, password string) (bool, *TokenInfo, error) {
	mab.lock.RLock()
	defer mab.lock.RUnlock()

	if storedPass, found := mab.validUsers[username]; found {
		if password == storedPass {
			return true, &TokenInfo{
				AdminRoles: mab.adminRoles,
			}, nil
		} else {
			return false, nil, nil
		}
	} else {
		return false, nil, nil
	}
}
