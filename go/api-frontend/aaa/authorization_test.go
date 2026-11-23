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

	m := NewTokenAuthorizationMiddleware(NewMemTokenBackend(1*time.Second, 1*time.Second, []string{}))

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

	backend := NewMemTokenBackend(1*time.Second, 1*time.Second, []string{})
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

	m := NewTokenAuthorizationMiddleware(NewMemTokenBackend(1*time.Second, 1*time.Second, []string{}))
	for n := 0; n < b.N; n++ {
		m.isAuthorizedAdminActions(ctx, "GET", "/api/v1/nodes", map[string]bool{"NODES_READ": true})
	}
}

func BenchmarkIsAuthorizedAdminActionsDynamic(b *testing.B) {
	ctx := log.LoggerNewContext(context.Background())

	m := NewTokenAuthorizationMiddleware(NewMemTokenBackend(1*time.Second, 1*time.Second, []string{}))
	for n := 0; n < b.N; n++ {
		m.isAuthorizedAdminActions(ctx, "GET", "/api/v1/node/00:11:22:33:44:55", map[string]bool{"NODES_READ": true})
	}
}

func TestPftestAdminRoleMapping(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())

	m := NewTokenAuthorizationMiddleware(NewMemTokenBackend(1*time.Second, 1*time.Second, []string{}))

	// PFTEST_CREATE is the role POST /api/v1/pftest/* maps to via the
	// explicit pathAdminRolesMap entry — not the SYSTEM fall-through.
	for _, path := range []string{
		"/api/v1/pftest/authentication",
		"/api/v1/pftest/profile_filter",
		"/api/v1/pftest/cluster/authentication",
		"/api/v1/pftest/cluster/profile_filter",
	} {
		if _, err := m.isAuthorizedAdminActions(ctx, "POST", path, map[string]bool{"PFTEST_CREATE": true}); err != nil {
			t.Errorf("POST %s with PFTEST_CREATE should be authorized, error: %s", path, err)
		}

		if _, err := m.isAuthorizedAdminActions(ctx, "POST", path, map[string]bool{"SERVICES_READ": true}); err == nil {
			t.Errorf("POST %s with only SERVICES_READ must be denied", path)
		}

		// SYSTEM_CREATE used to be the implicit fall-through requirement;
		// the explicit PFTEST mapping must take precedence.
		if _, err := m.isAuthorizedAdminActions(ctx, "POST", path, map[string]bool{"SYSTEM_CREATE": true}); err == nil {
			t.Errorf("POST %s with SYSTEM_CREATE must be denied now that PFTEST is explicit", path)
		}
	}
}

// Any admin can list the UI plugins and reach them (the UI filters their
// menus, the api handler checks the can of the manifests), this does not need
// pfconfig, unlike the test above
func TestUiPluginsAllowedToAnyAdmin(t *testing.T) {
	ctx := context.Background()
	m := &TokenAuthorizationMiddleware{}
	for _, roles := range []map[string]bool{{}, {"NODES_READ": true}} {
		for _, c := range []struct{ method, path string }{
			{"GET", "/api/v1/plugins"},
			{"GET", "/api/v1/plugin/acme/items"},
			{"POST", "/api/v1/plugin/acme/items"},
			{"DELETE", "/api/v1/plugin/acme/items/a"},
		} {
			if res, err := m.isAuthorizedAdminActions(ctx, c.method, c.path, roles); !res {
				t.Errorf("%s %s was unauthorized, error: %v", c.method, c.path, err)
			}
		}
	}
	// the other paths keep their admin role
	if res, _ := m.isAuthorizedAdminActions(ctx, "GET", "/api/v1/config/admin_roles", map[string]bool{"NODES_READ": true}); res {
		t.Error("/api/v1/config/admin_roles was authorized without ADMIN_ROLES_READ")
	}
	// the list is matched exactly: a path that only starts with it falls to
	// the SYSTEM role
	// the UI code of a bundle plugin: any admin, the handler checks menu.can
	for _, path := range []string{"/api/v1/plugins/acme/bundle.js", "/api/v1/plugins/a-b_c/bundle.js"} {
		if res, err := m.isAuthorizedAdminActions(ctx, "GET", path, map[string]bool{"NODES_READ": true}); !res {
			t.Errorf("%s was not authorized to any admin: %v", path, err)
		}
	}
	for _, path := range []string{"/api/v1/pluginsX", "/api/v1/plugins/../config/admin_roles", "/api/v1/plugins/x",
		"/api/v1/plugins/Acme/bundle.js", "/api/v1/plugins/acme/bundle.jsx", "/api/v1/plugins/../bundle.js", "/api/v1/plugins/a/b/bundle.js"} {
		if res, _ := m.isAuthorizedAdminActions(ctx, "GET", path, map[string]bool{"NODES_READ": true}); res {
			t.Errorf("%s was authorized to any admin", path)
		}
		if res, err := m.isAuthorizedAdminActions(ctx, "GET", path, map[string]bool{"SYSTEM_READ": true}); !res {
			t.Errorf("%s was not authorized with SYSTEM_READ: %v", path, err)
		}
	}
}

func TestPkiAdminRoleMapping(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())

	m := NewTokenAuthorizationMiddleware(NewMemTokenBackend(1*time.Second, 1*time.Second, []string{}))

	for _, c := range []struct {
		method, path, role string
	}{
		{"GET", "/api/v1/pki/certs", "PKI_READ"},
		{"POST", "/api/v1/pki/certs/search", "PKI_READ"},
		{"GET", "/api/v1/pki/cert/3", "PKI_READ"},
		{"POST", "/api/v1/pki/cert/3/download", "PKI_CREATE"},
		{"POST", "/api/v1/pki/cert/3/email", "PKI_CREATE"},
		{"POST", "/api/v1/pki/certs", "PKI_CREATE"},
		{"PATCH", "/api/v1/pki/profile/1", "PKI_UPDATE"},
		{"DELETE", "/api/v1/pki/cert/3/1", "PKI_DELETE"},
		{"GET", "/api/v1/pki/scepservers", "PKI_READ"},
	} {
		if _, err := m.isAuthorizedAdminActions(ctx, c.method, c.path, map[string]bool{c.role: true}); err != nil {
			t.Errorf("%s %s with %s should be authorized, error: %s", c.method, c.path, c.role, err)
		}

		// The PKI API used to fall through to the SYSTEM role
		systemRole := "SYSTEM" + c.role[len("PKI"):]
		if _, err := m.isAuthorizedAdminActions(ctx, c.method, c.path, map[string]bool{systemRole: true}); err == nil {
			t.Errorf("%s %s with %s must be denied", c.method, c.path, systemRole)
		}
	}

	// Building a PKCS#12 with the private key is not a read
	for _, path := range []string{"/api/v1/pki/cert/3/download", "/api/v1/pki/cert/3/email"} {
		if _, err := m.isAuthorizedAdminActions(ctx, "POST", path, map[string]bool{"PKI_READ": true}); err == nil {
			t.Errorf("POST %s with only PKI_READ must be denied", path)
		}
	}
}
