package aaa

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/davecgh/go-spew/spew"
	"github.com/inverse-inc/packetfence/go/log"
)

func TestTokenAuthorizationMiddlewareIsAuthorized(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())

	m := NewTokenAuthorizationMiddleware(NewMemTokenBackend(1 * time.Second))

	var res bool
	var err error

	// Test a valid GET
	res, err = m.IsAuthorized(ctx, "GET", "/config/violations", map[string]bool{
		"VIOLATIONS_READ": true,
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid POST
	res, err = m.IsAuthorized(ctx, "POST", "/config/violations", map[string]bool{
		"VIOLATIONS_CREATE": true,
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid PUT
	res, err = m.IsAuthorized(ctx, "PUT", "/config/violations", map[string]bool{
		"VIOLATIONS_UPDATE": true,
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid PATCH
	res, err = m.IsAuthorized(ctx, "PATCH", "/config/violations", map[string]bool{
		"VIOLATIONS_UPDATE": true,
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid DELETE
	res, err = m.IsAuthorized(ctx, "DELETE", "/config/violations", map[string]bool{
		"VIOLATIONS_DELETE": true,
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test an invalid GET
	res, err = m.IsAuthorized(ctx, "GET", "/config/violations", map[string]bool{
		"SYSTEM_READ": true,
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid POST
	res, err = m.IsAuthorized(ctx, "POST", "/config/violations", map[string]bool{
		"SYSTEM_READ": true,
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid PUT
	res, err = m.IsAuthorized(ctx, "PUT", "/config/violations", map[string]bool{
		"SYSTEM_READ": true,
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid PATCH
	res, err = m.IsAuthorized(ctx, "PATCH", "/config/violations", map[string]bool{
		"SYSTEM_READ": true,
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid DELETE
	res, err = m.IsAuthorized(ctx, "DELETE", "/config/violations", map[string]bool{
		"SYSTEM_READ": true,
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test empty roles
	res, err = m.IsAuthorized(ctx, "GET", "/config/violations", map[string]bool{})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}
}

func TestAdminRolesForToken(t *testing.T) {
	backend := NewMemTokenBackend(1 * time.Second)
	m := NewTokenAuthorizationMiddleware(backend)
	token := "token-is-so-pretty"

	roles := m.AdminRolesForToken(token)

	if len(roles) != 0 {
		t.Error("Got some roles for an existant token", spew.Sdump(roles))
	}

	backend.StoreAdminRolesForToken(token, []string{"SYSTEM_READ"})

	roles = m.AdminRolesForToken(token)

	if len(roles) != 1 {
		t.Error("Didn't get the right amount of roles for an existing token", spew.Sdump(roles))
	}

}

func TestTokenAuthorizationMiddlewareBearerRequestIsAuthorized(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())

	backend := NewMemTokenBackend(1 * time.Second)
	m := NewTokenAuthorizationMiddleware(backend)

	token := "wow-such-beauty-token"

	// Test inexistant token
	req, _ := http.NewRequest("GET", "/users", nil)
	addBearerTokenToTestRequest(req, token)

	res, err := m.BearerRequestIsAuthorized(ctx, req)

	if res {
		t.Error("Unauthenticated request has succeeded instead of failing", err)
	}

	// Test valid token with valid role
	backend.StoreAdminRolesForToken(token, []string{"USERS_READ"})

	res, err = m.BearerRequestIsAuthorized(ctx, req)

	if !res {
		t.Error("Authenticated request has failed instead of succeeding", err)
	}

	// Test valid token with invalid role
	req, _ = http.NewRequest("POST", "/users", nil)

	res, err = m.BearerRequestIsAuthorized(ctx, req)

	if res {
		t.Error("Unauthenticated request has succeeded instead of failing", err)
	}

}

func addBearerTokenToTestRequest(r *http.Request, token string) {
	r.Header.Set("Authorization", "Bearer "+token)
}
