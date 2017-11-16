package aaa

import (
	"testing"
	"time"

	"github.com/davecgh/go-spew/spew"
)

func TestMemTokenBackend(t *testing.T) {
	b := NewMemTokenBackend(1 * time.Second)
	token := "my-beautiful-token"

	if b.TokenIsValid(token) {
		t.Error("Non existing token is invalid")
	}

	tenantId := b.TenantIdForToken(token)

	if tenantId != -1 {
		t.Error("Got a tenant ID for an inexisting token")
	}

	roles := b.AdminRolesForToken(token)

	if len(roles) != 0 {
		t.Error("Got some roles for an existant token", spew.Sdump(roles))
	}

	b.StoreTokenInfo(token, &TokenInfo{
		AdminRoles: map[string]bool{
			"USERS_READ":  true,
			"SYSTEM_READ": true,
		},
		TenantId: 1,
	})

	if !b.TokenIsValid(token) {
		t.Error("Existing token is not valid")
	}

	tenantId = b.TenantIdForToken(token)

	if tenantId != 1 {
		t.Error("Got an invalid tenant ID for a valid token")
	}

	roles = b.AdminRolesForToken(token)

	if len(roles) != 2 {
		t.Error("Got the wrong amount of roles for an existant token", spew.Sdump(roles))
	}

	// Test the expiration
	time.Sleep(1 * time.Second)

	if b.TokenIsValid(token) {
		t.Error("Non existing token is invalid")
	}

	tenantId = b.TenantIdForToken(token)

	if tenantId != -1 {
		t.Error("Got a tenant ID for an expired token")
	}

	roles = b.AdminRolesForToken(token)

	if len(roles) != 0 {
		t.Error("Got some roles for an expired token", spew.Sdump(roles))
	}

}
