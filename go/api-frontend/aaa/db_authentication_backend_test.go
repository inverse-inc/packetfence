package aaa

import (
	"context"
	"database/sql"
	"fmt"
	"testing"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
)

func buildDbConn(ctx context.Context) *sql.DB {

	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Database)

	dbConfig := pfconfigdriver.Config.PfConf.Database
	proto := "tcp"

	if dbConfig.Host == "localhost" {
		proto = "unix"
	}

	uri := fmt.Sprintf("%s:%s@%s(%s)/%s?parseTime=true", dbConfig.User, dbConfig.Pass, proto, dbConfig.Host, dbConfig.Db)

	db, err := sql.Open("mysql", uri)

	if err != nil {
		log.LoggerWContext(ctx).Error(fmt.Sprintf("Error while connecting to DB: %s", err))
	}

	return db
}

func TestDbAuthenticationBackend(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())
	dab := NewDbAuthenticationBackend(ctx, buildDbConn(ctx), "api_users")

	// Test valid user
	dab.SetUser(ctx, &ApiUser{
		Username:    "bob",
		Password:    "garauge",
		ValidFrom:   time.Date(0, 0, 0, 0, 0, 0, 0, time.UTC),
		Expiration:  time.Date(2038, 01, 01, 00, 00, 00, 00, time.UTC),
		AccessLevel: "Node Manager",
		TenantId:    1,
	})

	auth, _, err := dab.Authenticate(ctx, "bob", "garauge")

	if !auth {
		t.Error("Auth failed for a valid user", err)
	}

	if err != nil {
		t.Error("An error was returned for a valid authentication")
	}

	// Test expired user
	dab.SetUser(ctx, &ApiUser{
		Username:    "bob",
		Password:    "garauge",
		ValidFrom:   time.Date(0, 0, 0, 0, 0, 0, 0, time.UTC),
		Expiration:  time.Date(2000, 01, 01, 00, 00, 00, 00, time.UTC),
		AccessLevel: "Node Manager",
		TenantId:    1,
	})

	auth, _, err = dab.Authenticate(ctx, "bob", "garauge")

	if auth {
		t.Error("Auth succeeded for an invalid user", err)
	}

	if err == nil {
		t.Error("No error was returned when the auth failed")
	}

	// Test not yet valid user
	dab.SetUser(ctx, &ApiUser{
		Username:    "bob",
		Password:    "garauge",
		ValidFrom:   time.Date(2037, 12, 31, 0, 0, 0, 0, time.UTC),
		Expiration:  time.Date(2038, 01, 01, 00, 00, 00, 00, time.UTC),
		AccessLevel: "Node Manager",
		TenantId:    1,
	})

	auth, _, err = dab.Authenticate(ctx, "bob", "garauge")

	if auth {
		t.Error("Auth succeeded for an invalid user", err)
	}

	if err == nil {
		t.Error("No error was returned when the auth failed")
	}

	// Test invalid password
	dab.SetUser(ctx, &ApiUser{
		Username:    "bob",
		Password:    "badpwd",
		ValidFrom:   time.Date(0, 0, 0, 0, 0, 0, 0, time.UTC),
		Expiration:  time.Date(2038, 01, 01, 00, 00, 00, 00, time.UTC),
		AccessLevel: "Node Manager",
		TenantId:    1,
	})

	auth, _, err = dab.Authenticate(ctx, "bob", "garauge")

	if auth {
		t.Error("Auth succeeded for an invalid user", err)
	}

	if err == nil {
		t.Error("No error was returned when the auth failed")
	}

	// Test invalid user
	auth, _, err = dab.Authenticate(ctx, "sylvie", "garauge")

	if auth {
		t.Error("Auth succeeded for an invalid user", err)
	}

	if err == nil {
		t.Error("No error was returned when the auth failed")
	}

}

func TestDbAuthenticationBackendBuildTokenInfo(t *testing.T) {
	ctx := log.LoggerNewContext(context.Background())
	dab := NewDbAuthenticationBackend(ctx, buildDbConn(ctx), "api_users")

	// An admin role with a default tenant
	ti := dab.buildTokenInfo(ctx, &ApiUser{
		AccessLevel: "Node Manager",
	})

	if len(ti.AdminRoles) != 4 {
		t.Error("Wrong amount of admin roles")
	}

	if ti.TenantId != 0 {
		t.Error("Wrong tenant")
	}

	// Test another tenant
	ti = dab.buildTokenInfo(ctx, &ApiUser{
		AccessLevel: "Node Manager",
		TenantId:    1,
	})

	if len(ti.AdminRoles) != 4 {
		t.Error("Wrong amount of admin roles")
	}

	if ti.TenantId != 1 {
		t.Error("Wrong tenant")
	}

	// Test having multiple roles
	ti = dab.buildTokenInfo(ctx, &ApiUser{
		AccessLevel: "Node Manager, Violation Manager",
	})

	if len(ti.AdminRoles) != 9 {
		t.Error("Wrong amount of admin roles")
	}

	// Test having a single invalid role
	ti = dab.buildTokenInfo(ctx, &ApiUser{
		AccessLevel: "Vidange",
	})

	if len(ti.AdminRoles) != 0 {
		t.Error("Wrong amount of admin roles")
	}

	// Test having a mix of valid and invalid roles
	ti = dab.buildTokenInfo(ctx, &ApiUser{
		AccessLevel: "Node Manager, Vidange",
	})

	if len(ti.AdminRoles) != 4 {
		t.Error("Wrong amount of admin roles")
	}

	// Test having no roles at all
	ti = dab.buildTokenInfo(ctx, &ApiUser{})

	if len(ti.AdminRoles) != 0 {
		t.Error("Wrong amount of admin roles")
	}
}
