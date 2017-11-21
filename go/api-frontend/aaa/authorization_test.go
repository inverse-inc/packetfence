package aaa

import (
	"context"
	"fmt"
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
	res, err = m.IsAuthorized(ctx, "GET", "/api/v1/config/violations", 0, &TokenInfo{
		AdminRoles: map[string]bool{
			"VIOLATIONS_READ": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid POST
	res, err = m.IsAuthorized(ctx, "POST", "/api/v1/config/violations", 0, &TokenInfo{
		AdminRoles: map[string]bool{
			"VIOLATIONS_CREATE": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid PUT
	res, err = m.IsAuthorized(ctx, "PUT", "/api/v1/config/violations", 0, &TokenInfo{
		AdminRoles: map[string]bool{
			"VIOLATIONS_UPDATE": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid PATCH
	res, err = m.IsAuthorized(ctx, "PATCH", "/api/v1/config/violations", 0, &TokenInfo{
		AdminRoles: map[string]bool{
			"VIOLATIONS_UPDATE": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid DELETE
	res, err = m.IsAuthorized(ctx, "DELETE", "/api/v1/config/violations", 0, &TokenInfo{
		AdminRoles: map[string]bool{
			"VIOLATIONS_DELETE": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test an invalid GET
	res, err = m.IsAuthorized(ctx, "GET", "/api/v1/config/violations", 0, &TokenInfo{
		AdminRoles: map[string]bool{
			"SYSTEM_READ": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid POST
	res, err = m.IsAuthorized(ctx, "POST", "/api/v1/config/violations", 0, &TokenInfo{
		AdminRoles: map[string]bool{
			"SYSTEM_READ": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid PUT
	res, err = m.IsAuthorized(ctx, "PUT", "/api/v1/config/violations", 0, &TokenInfo{
		AdminRoles: map[string]bool{
			"SYSTEM_READ": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid PATCH
	res, err = m.IsAuthorized(ctx, "PATCH", "/api/v1/config/violations", 0, &TokenInfo{
		AdminRoles: map[string]bool{
			"SYSTEM_READ": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid DELETE
	res, err = m.IsAuthorized(ctx, "DELETE", "/api/v1/config/violations", 0, &TokenInfo{
		AdminRoles: map[string]bool{
			"SYSTEM_READ": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test empty roles
	res, err = m.IsAuthorized(ctx, "GET", "/api/v1/config/violations", 0, &TokenInfo{
		AdminRoles: map[string]bool{},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test valid universal tenant ID
	res, err = m.IsAuthorized(ctx, "DELETE", "/api/v1/config/violations", 1, &TokenInfo{
		AdminRoles: map[string]bool{
			"VIOLATIONS_DELETE": true,
		},
		TenantId: 0,
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test valid scoped tenant ID
	res, err = m.IsAuthorized(ctx, "DELETE", "/api/v1/config/violations", 1, &TokenInfo{
		AdminRoles: map[string]bool{
			"VIOLATIONS_DELETE": true,
		},
		TenantId: 1,
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test invalid scoped tenant ID
	res, err = m.IsAuthorized(ctx, "DELETE", "/api/v1/config/violations", 1, &TokenInfo{
		AdminRoles: map[string]bool{
			"VIOLATIONS_DELETE": true,
		},
		TenantId: 2,
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test invalid scoped tenant ID
	res, err = m.IsAuthorized(ctx, "DELETE", "/api/v1/config/violations", 1, &TokenInfo{
		AdminRoles: map[string]bool{
			"VIOLATIONS_DELETE": true,
		},
		TenantId: -1,
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
	req, _ := http.NewRequest("GET", "/api/v1/users", nil)
	addBearerTokenToTestRequest(req, token, 0)

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

	// Test valid token with scoped tenant ID without X-PacketFence-Tenant-Id header
	backend.StoreTokenInfo(token, &TokenInfo{
		AdminRoles: map[string]bool{
			"USERS_READ": true,
		},
		TenantId: 1,
	})

	addBearerTokenToTestRequest(req, token, 1)

	res, err = m.BearerRequestIsAuthorized(ctx, req)

	if !res {
		t.Error("Authenticated request has failed instead of succeeding", err)
	}

	if req.Header.Get("X-PacketFence-Tenant-Id") != "1" {
		t.Error("Request without X-PacketFence-Tenant-Id didn't get the header set to the token tenant ID")
	}

	// Test valid token with scoped tenant ID with X-PacketFence-Tenant-Id header
	backend.StoreTokenInfo(token, &TokenInfo{
		AdminRoles: map[string]bool{
			"USERS_READ": true,
		},
		TenantId: 0,
	})

	addBearerTokenToTestRequest(req, token, 1)

	res, err = m.BearerRequestIsAuthorized(ctx, req)

	if !res {
		t.Error("Authenticated request has failed instead of succeeding", err)
	}

	// Test valid token with wrong scoped X-PacketFence-Tenant-Id
	backend.StoreTokenInfo(token, &TokenInfo{
		AdminRoles: map[string]bool{
			"USERS_READ": true,
		},
		TenantId: 1,
	})

	addBearerTokenToTestRequest(req, token, 2)

	res, err = m.BearerRequestIsAuthorized(ctx, req)

	if res {
		t.Error("Unauthenticated request has succeeded instead of failing", err)
	}

	// Test valid token with invalid role
	req, _ = http.NewRequest("POST", "/api/v1/users", nil)

	res, err = m.BearerRequestIsAuthorized(ctx, req)

	if res {
		t.Error("Unauthenticated request has succeeded instead of failing", err)
	}

}

func addBearerTokenToTestRequest(r *http.Request, token string, tenantId int) {
	r.Header.Set("Authorization", "Bearer "+token)

	if tenantId != 0 {
		r.Header.Set("X-PacketFence-Tenant-Id", fmt.Sprintf("%d", tenantId))
	}
}
