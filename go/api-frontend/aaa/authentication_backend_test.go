package aaa

import (
	"context"
	"testing"

	"github.com/inverse-inc/packetfence/go/log"
)

func TestMemAuthenticationBackend(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())
	mab := NewMemAuthenticationBackend(map[string]string{"bob": "garauge"}, map[string]bool{"SYSTEM_READ": true})

	if mab.validUsers["bob"] != "garauge" {
		t.Error("User wasn't set properly in constructor")
	}

	mab.SetUser("sylvie", "mannequine")

	if mab.validUsers["sylvie"] != "mannequine" {
		t.Error("User wasn't set properly via the SetUser")
	}

	// Valid user that was in the constructor
	auth, tokenInfo, err := mab.Authenticate(ctx, "bob", "garauge")

	if !auth {
		t.Error("User was unauthenticated although it presented valid credentials. error:", err)
	}

	if !tokenInfo.AdminRoles["SYSTEM_READ"] {
		t.Error("User doesn't have the right admin roles")
	}

	if tokenInfo.TenantId != 0 {
		t.Error("User doesn't have the right tenant ID")
	}

	if err != nil {
		t.Error("There was an error while performing a valid authentication. error:", err)
	}

	// Valid user that was added
	auth, tokenInfo, err = mab.Authenticate(ctx, "sylvie", "mannequine")

	if !auth {
		t.Error("User was unauthenticated although it presented valid credentials. error:", err)
	}

	if !tokenInfo.AdminRoles["SYSTEM_READ"] {
		t.Error("User doesn't have the right admin roles")
	}

	if tokenInfo.TenantId != 0 {
		t.Error("User doesn't have the right tenant ID")
	}

	if err != nil {
		t.Error("There was an error while performing a valid authentication. error:", err)
	}

	// Invalid password
	auth, tokenInfo, err = mab.Authenticate(ctx, "sylvie", "badpwd")

	if auth {
		t.Error("User was authenticated although the password is invalid", err)
	}

	if tokenInfo != nil {
		t.Error("Token info isn't nil although the auth failed")
	}

	if err != nil {
		t.Error("There is an error for a normal auth failure", err)
	}

	// Invalid user
	auth, tokenInfo, err = mab.Authenticate(ctx, "baduser", "badpwd")

	if auth {
		t.Error("User was authenticated although the user is invalid", err)
	}

	if tokenInfo != nil {
		t.Error("Token info isn't nil although the auth failed")
	}

	if err != nil {
		t.Error("There is an error for a normal auth failure", err)
	}
}
