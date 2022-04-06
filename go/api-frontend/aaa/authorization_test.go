package aaa

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/inverse-inc/go-utils/log"
)

func TestTokenAuthorizationMiddlewareIsAuthorized(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())

	m := NewTokenAuthorizationMiddleware(NewMemTokenBackend(1*time.Second, 1*time.Second))

	var res bool
	var err error

	// Test a valid GET
	res, err = m.IsAuthorized(ctx, "GET", "/api/v1/nodes", &TokenInfo{
		AdminRoles: map[string]bool{
			"NodesRead": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test the role suffix override
	res, err = m.IsAuthorized(ctx, "POST", "/api/v1/nodes/network_graph", &TokenInfo{
		AdminRoles: map[string]bool{
			"NodesRead": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	res, err = m.IsAuthorized(ctx, "GET", "/api/v1/current_user", &TokenInfo{
		AdminRoles: map[string]bool{
			"NodesRead": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a search POST
	res, err = m.IsAuthorized(ctx, "POST", "/api/v1/nodes/search", &TokenInfo{
		AdminRoles: map[string]bool{
			"NodesRead": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid GET with a parameter
	res, err = m.IsAuthorized(ctx, "GET", "/api/v1/node/00:11:22:33:44:55", &TokenInfo{
		AdminRoles: map[string]bool{
			"NodesRead": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid POST
	res, err = m.IsAuthorized(ctx, "POST", "/api/v1/nodes", &TokenInfo{
		AdminRoles: map[string]bool{
			"NodesCreate": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid PUT
	res, err = m.IsAuthorized(ctx, "PUT", "/api/v1/nodes", &TokenInfo{
		AdminRoles: map[string]bool{
			"NodesUpdate": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid PATCH
	res, err = m.IsAuthorized(ctx, "PATCH", "/api/v1/nodes", &TokenInfo{
		AdminRoles: map[string]bool{
			"NodesUpdate": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid DELETE
	res, err = m.IsAuthorized(ctx, "DELETE", "/api/v1/nodes", &TokenInfo{
		AdminRoles: map[string]bool{
			"NodesDelete": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test an invalid GET
	res, err = m.IsAuthorized(ctx, "GET", "/api/v1/nodes", &TokenInfo{
		AdminRoles: map[string]bool{
			"SystemRead": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid POST
	res, err = m.IsAuthorized(ctx, "POST", "/api/v1/nodes", &TokenInfo{
		AdminRoles: map[string]bool{
			"SystemRead": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid PUT
	res, err = m.IsAuthorized(ctx, "PUT", "/api/v1/nodes", &TokenInfo{
		AdminRoles: map[string]bool{
			"SystemRead": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid PATCH
	res, err = m.IsAuthorized(ctx, "PATCH", "/api/v1/nodes", &TokenInfo{
		AdminRoles: map[string]bool{
			"SystemRead": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid DELETE
	res, err = m.IsAuthorized(ctx, "DELETE", "/api/v1/nodes", &TokenInfo{
		AdminRoles: map[string]bool{
			"SystemRead": true,
		},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test empty roles
	res, err = m.IsAuthorized(ctx, "GET", "/api/v1/nodes", &TokenInfo{
		AdminRoles: map[string]bool{},
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test valid universal tenant ID
	res, err = m.IsAuthorized(ctx, "DELETE", "/api/v1/nodes", &TokenInfo{
		AdminRoles: map[string]bool{
			"NodesDelete": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test valid scoped tenant ID
	res, err = m.IsAuthorized(ctx, "DELETE", "/api/v1/nodes", &TokenInfo{
		AdminRoles: map[string]bool{
			"NodesDelete": true,
		},
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

    _, err = m.isAuthorizedAdminActions(ctx, "GET", "/api/v1.1/reports", map[string]bool{"REPORTS_READ": true})

	if err != nil {
		t.Error("Request was not authorized although it should have gone through, error:", err)
	}

}

func TestTokenAuthorizationMiddlewareBearerRequestIsAuthorized(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())

	backend := NewMemTokenBackend(1*time.Second, 1*time.Second)
	m := NewTokenAuthorizationMiddleware(backend)

	token := "wow-such-beauty-token"

	// Test inexistant token
	req, _ := http.NewRequest("GET", "/api/v1/users", nil)
	addBearerTokenToTestRequest(req, token)

	res, err := m.BearerRequestIsAuthorized(ctx, req)

	if res {
		t.Error("Unauthenticated request has succeeded instead of failing", err)
	}

	// Test valid token with valid role
	backend.StoreTokenInfo(token, &TokenInfo{
		AdminRoles: map[string]bool{
			"UsersRead": true,
		},
	})

	res, err = m.BearerRequestIsAuthorized(ctx, req)

	if !res {
		t.Error("Authenticated request has failed instead of succeeding", err)
	}

	backend.StoreTokenInfo(token, &TokenInfo{
		AdminRoles: map[string]bool{
			"UsersRead": true,
		},
	})

	addBearerTokenToTestRequest(req, token)

	res, err = m.BearerRequestIsAuthorized(ctx, req)

	if !res {
		t.Error("Authenticated request has failed instead of succeeding", err)
	}

	if req.Header.Get("X-PacketFEnce-Admin-Roles") != "UsersRead" {
		t.Error("Didn't set the admin roles header properly")
	}

	backend.StoreTokenInfo(token, &TokenInfo{
		AdminRoles: map[string]bool{
			"UsersRead": true,
		},
	})

	addBearerTokenToTestRequest(req, token)

	res, err = m.BearerRequestIsAuthorized(ctx, req)

	if !res {
		t.Error("Authenticated request has failed instead of succeeding", err)
	}

	// Test valid token with invalid role
	req, _ = http.NewRequest("POST", "/api/v1/users", nil)

	res, err = m.BearerRequestIsAuthorized(ctx, req)

	if res {
		t.Error("Unauthenticated request has succeeded instead of failing", err)
	}


}

func addBearerTokenToTestRequest(r *http.Request, token string) {
	r.Header.Set("Authorization", "Bearer "+token)
}

func BenchmarkIsAuthorizedAdminActionsStatic(b *testing.B) {
	ctx := log.LoggerNewContext(context.Background())

	m := NewTokenAuthorizationMiddleware(NewMemTokenBackend(1*time.Second, 1*time.Second))
	for n := 0; n < b.N; n++ {
		m.isAuthorizedAdminActions(ctx, "GET", "/api/v1/nodes", map[string]bool{"NODES_READ": true})
	}
}

func BenchmarkIsAuthorizedAdminActionsDynamic(b *testing.B) {
	ctx := log.LoggerNewContext(context.Background())

	m := NewTokenAuthorizationMiddleware(NewMemTokenBackend(1*time.Second, 1*time.Second))
	for n := 0; n < b.N; n++ {
		m.isAuthorizedAdminActions(ctx, "GET", "/api/v1/node/00:11:22:33:44:55", map[string]bool{"NODES_READ": true})
	}
}
