package aaa

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/inverse-inc/packetfence/go/log"
)

func TestTokenAuthorizationMiddlewareIsAuthorized(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())

	m := NewTokenAuthorizationMiddleware(NewMemTokenBackend(1 * time.Second))

	var res bool
	var err error

	// Test a valid GET
	res, err = m.IsAuthorized(ctx, "GET", "/config/violations", &TokenInfo{
		AdminRoles: map[string]bool{
			"VIOLATIONS_READ": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid POST
	res, err = m.IsAuthorized(ctx, "POST", "/config/violations", &TokenInfo{
		AdminRoles: map[string]bool{
			"VIOLATIONS_CREATE": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid PUT
	res, err = m.IsAuthorized(ctx, "PUT", "/config/violations", &TokenInfo{
		AdminRoles: map[string]bool{
			"VIOLATIONS_UPDATE": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid PATCH
	res, err = m.IsAuthorized(ctx, "PATCH", "/config/violations", &TokenInfo{
		AdminRoles: map[string]bool{
			"VIOLATIONS_UPDATE": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid DELETE
	res, err = m.IsAuthorized(ctx, "DELETE", "/config/violations", &TokenInfo{
		AdminRoles: map[string]bool{
			"VIOLATIONS_DELETE": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test an invalid GET
	res, err = m.IsAuthorized(ctx, "GET", "/config/violations", &TokenInfo{
		AdminRoles: map[string]bool{
			"SYSTEM_READ": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid POST
	res, err = m.IsAuthorized(ctx, "POST", "/config/violations", &TokenInfo{
		AdminRoles: map[string]bool{
			"SYSTEM_READ": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid PUT
	res, err = m.IsAuthorized(ctx, "PUT", "/config/violations", &TokenInfo{
		AdminRoles: map[string]bool{
			"SYSTEM_READ": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid PATCH
	res, err = m.IsAuthorized(ctx, "PATCH", "/config/violations", &TokenInfo{
		AdminRoles: map[string]bool{
			"SYSTEM_READ": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid DELETE
	res, err = m.IsAuthorized(ctx, "DELETE", "/config/violations", &TokenInfo{
		AdminRoles: map[string]bool{
			"SYSTEM_READ": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test empty roles
	res, err = m.IsAuthorized(ctx, "GET", "/config/violations", &TokenInfo{
		AdminRoles: map[string]bool{},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
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
	backend.StoreTokenInfo(token, &TokenInfo{
		AdminRoles: map[string]bool{
			"USERS_READ": true,
		},
	})

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
