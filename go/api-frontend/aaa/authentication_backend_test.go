package aaa

import "testing"

func TestMemAuthenticationBackend(t *testing.T) {
	mab := NewMemAuthenticationBackend(map[string]string{"bob": "garauge"}, []string{"SYSTEM_READ"})

	if mab.validUsers["bob"] != "garauge" {
		t.Error("User wasn't set properly in constructor")
	}

	mab.SetUser("sylvie", "mannequine")

	if mab.validUsers["sylvie"] != "mannequine" {
		t.Error("User wasn't set properly via the SetUser")
	}

	auth, tokenInfo, err := mab.Authenticate("bob", "garauge")

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

	auth, tokenInfo, err = mab.Authenticate("sylvie", "mannequine")

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
}
