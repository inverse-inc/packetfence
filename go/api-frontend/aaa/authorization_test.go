package aaa

import (
	"context"
	"testing"

	"github.com/inverse-inc/packetfence/go/log"
)

func TestIsAuthorized(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())

	var res bool
	var err error

	// Test a valid GET
	res, err = IsAuthorized(ctx, "GET", "/config/violations", map[string]bool{
		"VIOLATIONS_READ": true,
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid POST
	res, err = IsAuthorized(ctx, "POST", "/config/violations", map[string]bool{
		"VIOLATIONS_CREATE": true,
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid PUT
	res, err = IsAuthorized(ctx, "PUT", "/config/violations", map[string]bool{
		"VIOLATIONS_UPDATE": true,
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid PATCH
	res, err = IsAuthorized(ctx, "PATCH", "/config/violations", map[string]bool{
		"VIOLATIONS_UPDATE": true,
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test a valid DELETE
	res, err = IsAuthorized(ctx, "DELETE", "/config/violations", map[string]bool{
		"VIOLATIONS_DELETE": true,
	})

	if !res {
		t.Error("Request was unauthorized although it should have gone through, error:", err)
	}

	// Test an invalid GET
	res, err = IsAuthorized(ctx, "GET", "/config/violations", map[string]bool{
		"SYSTEM_READ": true,
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid POST
	res, err = IsAuthorized(ctx, "POST", "/config/violations", map[string]bool{
		"SYSTEM_READ": true,
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid PUT
	res, err = IsAuthorized(ctx, "PUT", "/config/violations", map[string]bool{
		"SYSTEM_READ": true,
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid PATCH
	res, err = IsAuthorized(ctx, "PATCH", "/config/violations", map[string]bool{
		"SYSTEM_READ": true,
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test an invalid DELETE
	res, err = IsAuthorized(ctx, "DELETE", "/config/violations", map[string]bool{
		"SYSTEM_READ": true,
	})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}

	// Test empty roles
	res, err = IsAuthorized(ctx, "GET", "/config/violations", map[string]bool{})

	if res {
		t.Error("Request was authorized although it should haven't gone through, error:", err)
	}
}

func TestAdminRolesForToken(t *testing.T) {

}
