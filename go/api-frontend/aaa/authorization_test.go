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

// The remote terminal opens a root shell on the connector-remote, so all its
// routes require CONNECTORS_UPDATE, whatever the method.
func TestTerminalAdminRoleMapping(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())
	m := NewTokenAuthorizationMiddleware(NewMemTokenBackend(1*time.Second, 1*time.Second, []string{}))

	for _, method := range []string{"GET", "POST"} {
		for _, path := range []string{"/api/v1/terminal", "/api/v1/terminal/connector1/", "/api/v1/terminal/connector1/authorize/abc"} {
			if res, _ := m.isAuthorizedAdminActions(ctx, method, path, map[string]bool{"NODES_READ": true}); res {
				t.Errorf("%s %s was authorized without any CONNECTORS role", method, path)
			}
			if res, _ := m.isAuthorizedAdminActions(ctx, method, path, map[string]bool{"CONNECTORS_READ": true}); res {
				t.Errorf("%s %s was authorized with CONNECTORS_READ only", method, path)
			}
			if res, err := m.isAuthorizedAdminActions(ctx, method, path, map[string]bool{"CONNECTORS_UPDATE": true}); !res {
				t.Errorf("%s %s was not authorized with CONNECTORS_UPDATE, error: %v", method, path, err)
			}
		}
	}
}

// The domain form reads the connector serving a domain controller and the
// state of its NTLM services with the DOMAINS rights alone; everything else
// on the connector-remotes stays with CONNECTORS.
func TestPfconnectorRemotesDomainsAdminRoleMapping(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())
	m := NewTokenAuthorizationMiddleware(NewMemTokenBackend(1*time.Second, 1*time.Second, []string{}))

	for _, path := range []string{"/api/v1/pfconnector-remotes/for-ip/192.0.2.10", "/api/v1/pfconnector-remotes/connector1/status"} {
		for _, role := range []string{"DOMAINS_READ", "CONNECTORS_READ"} {
			if res, err := m.isAuthorizedAdminActions(ctx, "GET", path, map[string]bool{role: true}); !res {
				t.Errorf("GET %s was not authorized with %s, error: %v", path, role, err)
			}
		}
		for _, role := range []string{"DOMAINS_CREATE", "NODES_READ"} {
			if res, _ := m.isAuthorizedAdminActions(ctx, "GET", path, map[string]bool{role: true}); res {
				t.Errorf("GET %s was authorized with %s", path, role)
			}
		}
	}
	for _, test := range []struct{ method, path string }{
		{"GET", "/api/v1/pfconnector-remotes/connector1/uptime"},
		{"GET", "/api/v1/pfconnector-remotes/connector1/logs/pfconnector-client"},
		{"POST", "/api/v1/pfconnector-remotes/connector1/install"},
	} {
		if res, _ := m.isAuthorizedAdminActions(ctx, test.method, test.path, map[string]bool{"DOMAINS_READ": true, "DOMAINS_UPDATE": true}); res {
			t.Errorf("%s %s was authorized with the DOMAINS rights", test.method, test.path)
		}
	}
}

// Restarting or upgrading a connector-remote modifies an existing connector:
// it requires CONNECTORS_UPDATE, while reading its status, its logs or doing
// a DNS lookup only requires CONNECTORS_READ.
func TestPfconnectorRemotesAdminRoleMapping(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())
	m := NewTokenAuthorizationMiddleware(NewMemTokenBackend(1*time.Second, 1*time.Second, []string{}))

	tests := []struct {
		method, path, role string
	}{
		{"POST", "/api/v1/pfconnector-remotes/connector1/restart", "CONNECTORS_UPDATE"},
		{"POST", "/api/v1/pfconnector-remotes/connector1/upgrade", "CONNECTORS_UPDATE"},
		{"GET", "/api/v1/pfconnector-remotes/connector1/status", "CONNECTORS_READ"},
		{"GET", "/api/v1/pfconnector-remotes/connector1/uptime", "CONNECTORS_READ"},
		{"GET", "/api/v1/pfconnector-remotes/connector1/logs/pfconnector-client", "CONNECTORS_READ"},
		{"POST", "/api/v1/pfconnector-remotes/dns-lookup", "CONNECTORS_READ"},
	}
	for _, test := range tests {
		if res, err := m.isAuthorizedAdminActions(ctx, test.method, test.path, map[string]bool{test.role: true}); !res {
			t.Errorf("%s %s was not authorized with %s, error: %v", test.method, test.path, test.role, err)
		}
		for _, other := range []string{"CONNECTORS_READ", "CONNECTORS_CREATE", "CONNECTORS_UPDATE", "CONNECTORS_DELETE"} {
			if other == test.role {
				continue
			}
			if res, _ := m.isAuthorizedAdminActions(ctx, test.method, test.path, map[string]bool{other: true}); res {
				t.Errorf("%s %s was authorized with %s instead of %s", test.method, test.path, other, test.role)
			}
		}
	}
}

// The configuration of the connectors is managed with the CONNECTORS role,
// like the connector-remote actions, so that role is usable on its own.
func TestConfigConnectorsAdminRoleMapping(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())
	m := NewTokenAuthorizationMiddleware(NewMemTokenBackend(1*time.Second, 1*time.Second, []string{}))

	tests := []struct {
		method, path, role string
	}{
		{"GET", "/api/v1/config/connectors", "CONNECTORS_READ"},
		{"GET", "/api/v1/config/connector/connector1", "CONNECTORS_READ"},
		{"POST", "/api/v1/config/connectors", "CONNECTORS_CREATE"},
		{"PATCH", "/api/v1/config/connector/connector1", "CONNECTORS_UPDATE"},
		{"DELETE", "/api/v1/config/connector/connector1", "CONNECTORS_DELETE"},
	}
	for _, test := range tests {
		if res, err := m.isAuthorizedAdminActions(ctx, test.method, test.path, map[string]bool{test.role: true}); !res {
			t.Errorf("%s %s was not authorized with %s, error: %v", test.method, test.path, test.role, err)
		}
		if res, _ := m.isAuthorizedAdminActions(ctx, test.method, test.path, map[string]bool{"SYSTEM_READ": true, "SYSTEM_CREATE": true, "SYSTEM_UPDATE": true, "SYSTEM_DELETE": true}); res {
			t.Errorf("%s %s is still authorized with the SYSTEM role", test.method, test.path)
		}
	}
}
