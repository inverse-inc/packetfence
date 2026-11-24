package models

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"sync"
	"testing"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

const injectedID = "1 OR 1=1"

// dryRunHandler returns a handler on a DryRun gorm DB: no statement reaches
// a server, and every statement gorm builds is recorded.
func dryRunHandler(t *testing.T) (*types.Handler, func() []string) {
	t.Helper()
	db, err := gorm.Open(mysql.New(mysql.Config{
		DSN:                       "pf:pf@tcp(127.0.0.1:1)/pf",
		SkipInitializeWithVersion: true,
	}), &gorm.Config{
		DryRun:                 true,
		DisableAutomaticPing:   true,
		SkipDefaultTransaction: true, // a transaction would connect
	})
	if err != nil {
		t.Fatal(err)
	}

	var mu sync.Mutex
	var statements []string
	record := func(db *gorm.DB) {
		mu.Lock()
		defer mu.Unlock()
		statements = append(statements, db.Statement.SQL.String())
	}
	cb := db.Callback()
	cb.Query().After("gorm:query").Register("test:record", record)
	cb.Delete().After("gorm:delete").Register("test:record", record)
	cb.Update().After("gorm:update").Register("test:record", record)
	cb.Create().After("gorm:create").Register("test:record", record)
	cb.Row().After("gorm:row").Register("test:record", record)
	cb.Raw().After("gorm:raw").Register("test:record", record)

	ctx := context.Background()
	return &types.Handler{DB: db, Ctx: &ctx}, func() []string {
		mu.Lock()
		defer mu.Unlock()
		return append([]string(nil), statements...)
	}
}

// TestNonNumericIDIsRejected covers issue #9722: an {id} that isn't a
// number must never reach gorm as an inline condition, where it would be
// used as a raw WHERE clause.
func TestNonNumericIDIsRejected(t *testing.T) {
	params := map[string]string{"id": injectedID}
	cases := []struct {
		name string
		call func(h *types.Handler) (types.Info, error)
	}{
		{"CA.Resign", func(h *types.Handler) (types.Info, error) { return NewCAModel(h).Resign(params) }},
		{"CA.GenerateCSR", func(h *types.Handler) (types.Info, error) { return NewCAModel(h).GenerateCSR(params) }},
		{"CA.Update", func(h *types.Handler) (types.Info, error) { return NewCAModel(h).Update(params) }},
		{"Profile.Update", func(h *types.Handler) (types.Info, error) { return NewProfileModel(h).Update(params) }},
		{"Cert.Download", func(h *types.Handler) (types.Info, error) { return NewCertModel(h).Download(params) }},
		{"Cert.Resign", func(h *types.Handler) (types.Info, error) { return NewCertModel(h).Resign(params) }},
		{"CSR.New", func(h *types.Handler) (types.Info, error) { return NewCsrModel(h).New(params) }},
		{"SCEPServer.DelByID", func(h *types.Handler) (types.Info, error) { return NewSCEPServerModel(h).DelByID(params) }},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			h, statements := dryRunHandler(t)
			var info types.Info
			var err error
			// DryRun queries return no rows, so code that let the id
			// through may panic on the empty result: check the SQL first.
			panicked := func() (p interface{}) {
				defer func() { p = recover() }()
				info, err = c.call(h)
				return nil
			}()
			for _, s := range statements() {
				if strings.Contains(s, "OR 1=1") {
					t.Fatalf("the id reached the SQL: %s", s)
				}
			}
			if panicked != nil {
				t.Fatalf("panic: %v", panicked)
			}
			if !errors.Is(err, ErrInvalidID) {
				t.Fatalf("err = %v, want ErrInvalidID", err)
			}
			if info.Status != http.StatusBadRequest {
				t.Fatalf("Information.Status = %d, want 400", info.Status)
			}
		})
	}
}

func TestParseID(t *testing.T) {
	for _, val := range []string{"", "abc", "1 OR 1=1", "-1", "1.5", "99999999999999999999"} {
		if _, err := parseID(val); !errors.Is(err, ErrInvalidID) {
			t.Errorf("parseID(%q) err = %v, want ErrInvalidID", val, err)
		}
	}
	if id, err := parseID("42"); err != nil || id != 42 {
		t.Errorf("parseID(\"42\") = %d, %v, want 42, nil", id, err)
	}
}
