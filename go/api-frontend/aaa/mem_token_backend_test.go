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

	roles := b.AdminRolesForToken(token)

	if len(roles) != 0 {
		t.Error("Got some roles for an existant token", spew.Sdump(roles))
	}

	b.StoreAdminRolesForToken(token, []string{"USERS_READ", "SYSTEM_READ"})

	if !b.TokenIsValid(token) {
		t.Error("Existing token is not valid")
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

	roles = b.AdminRolesForToken(token)

	if len(roles) != 0 {
		t.Error("Got some roles for an expired token", spew.Sdump(roles))
	}

}
