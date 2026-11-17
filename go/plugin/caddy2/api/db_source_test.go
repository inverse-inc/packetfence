package api

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/inverse-inc/go-utils/log"
	"github.com/julienschmidt/httprouter"
	"gorm.io/gorm"
)

var errDBDown = errors.New("dial unix /var/lib/mysql/mysql.sock: connect: no such file or directory")

func failingSource(context.Context) (*gorm.DB, error) { return nil, errDBDown }

// While the database is down the DAL routes answer 503 with the cause instead
// of blocking or dereferencing a broken handle.
func TestDALHandlersReturn503WhenDatabaseUnavailable(t *testing.T) {
	ctx := log.LoggerDummyContext()
	router := httprouter.New()
	NewAdminApiAuditLog(ctx, failingSource).AddToRouter(router)
	NewAuthLog(ctx, failingSource).AddToRouter(router)
	NewDnsAuditLog(ctx, failingSource).AddToRouter(router)
	NewRadacctLog(ctx, failingSource).AddToRouter(router)
	NewRadiusAuditLog(ctx, failingSource).AddToRouter(router)
	NewWrix(ctx, failingSource).AddToRouter(router)

	for _, path := range []string{
		"/api/v1/admin_api_audit_logs",
		"/api/v1/auth_logs",
		"/api/v1/dns_audit_logs",
		"/api/v1/radacct_logs",
		"/api/v1/radius_audit_logs",
		"/api/v1/wrixes",
	} {
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
		if rec.Code != http.StatusServiceUnavailable {
			t.Errorf("%s: status %d, want 503", path, rec.Code)
			continue
		}
		var body RespBody
		if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
			t.Errorf("%s: body %q: %v", path, rec.Body.String(), err)
			continue
		}
		if len(body.Errors) == 0 || !strings.Contains(body.Errors[0].Message, "database unavailable") {
			t.Errorf("%s: errors = %+v", path, body.Errors)
		}
	}
}

func TestReportHelpersDegradeWhenDatabaseUnavailable(t *testing.T) {
	a := NewDynamicReport(log.LoggerDummyContext(), failingSource)
	if start, end := getDefaultDateRange(a, "1D"); start != "1970-01-01 00:00:00" || end != "2099-12-31 23:59:59" {
		t.Errorf("getDefaultDateRange = %q, %q; want the defaults", start, end)
	}
	if off := getUtcOffset(a); off != nil {
		t.Errorf("getUtcOffset = %v, want nil", *off)
	}
}

// Provisioning must not wait for the database: api-frontend serves many routes
// that do not need it, and a provision that blocks keeps the whole service
// (api-aaa, the perl API proxy, pfconnector) down for the outage.
func TestBuildHandlerDoesNotWaitForDatabase(t *testing.T) {
	old := gormFromConfig
	gormFromConfig = failingSource
	t.Cleanup(func() { gormFromConfig = old })

	m := &APIHandler{}
	done := make(chan error, 1)
	go func() { done <- m.buildHandler(log.LoggerDummyContext()) }()
	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("buildHandler: %v", err)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("buildHandler blocked on an unavailable database")
	}

	rec := httptest.NewRecorder()
	m.router.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/wrixes", nil))
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("GET /api/v1/wrixes: %d, want 503", rec.Code)
	}
}

// Without an injected handle, the raw pool is resolved on each use so a DSN
// change in pfconfig takes effect without a restart.
func TestSwitchIPsForMacsResolvesPoolPerUse(t *testing.T) {
	ctx := log.LoggerDummyContext()
	first := locationlogHandler(t, &locationlogDriver{switchIPs: map[string]string{"00:11:22:33:44:55": "10.1.2.3"}}).db
	second := locationlogHandler(t, &locationlogDriver{switchIPs: map[string]string{"00:11:22:33:44:55": "10.9.9.9"}}).db

	current := first
	old := sqlDBFromConfig
	sqlDBFromConfig = func(context.Context, ...string) (*sql.DB, error) { return current, nil }
	t.Cleanup(func() { sqlDBFromConfig = old })

	m := &APIHandler{}
	if got := m.switchIPsForMacs(ctx, []string{"00:11:22:33:44:55"}); got["00:11:22:33:44:55"] != "10.1.2.3" {
		t.Fatalf("first = %v", got)
	}
	current = second
	if got := m.switchIPsForMacs(ctx, []string{"00:11:22:33:44:55"}); got["00:11:22:33:44:55"] != "10.9.9.9" {
		t.Fatalf("after config change = %v", got)
	}
}

// fixedGorm serves one handle to every request (tests with their own DB).
func fixedGorm(gdb *gorm.DB) gormSource {
	return func(context.Context) (*gorm.DB, error) { return gdb, nil }
}
