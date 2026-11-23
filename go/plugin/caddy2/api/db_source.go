package api

import (
	"context"
	"database/sql"
	"errors"
	"net/http"

	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/db/dbgorm"
	"gorm.io/gorm"
)

// gormSource returns the GORM handle to use for one request.
type gormSource func(ctx context.Context) (*gorm.DB, error)

// Swapped by tests.
var (
	gormFromConfig  gormSource = dbgorm.FromConfig
	sqlDBFromConfig            = db.DbFromConfig
)

// gormForRequest resolves the handle for one request. When the database is
// unavailable it answers 503 with the cause and returns false.
func gormForRequest(ctx context.Context, w http.ResponseWriter, src gormSource) (**gorm.DB, bool) {
	gdb, err := src(ctx)
	if err != nil {
		var body RespBody
		setError(&body, errors.New("database unavailable: "+err.Error()), http.StatusServiceUnavailable)
		outputResult(w, body)
		return nil, false
	}
	return &gdb, true
}

// sqlDB returns the raw shared pool. Tests inject h.db; otherwise it is
// resolved on each use (a cached lookup), which picks up a DSN change in
// pfconfig. Never Close it.
func (h *APIHandler) sqlDB(ctx context.Context) (*sql.DB, error) {
	sqlDBLock.RLock()
	override := h.db
	sqlDBLock.RUnlock()
	if override != nil {
		return override, nil
	}
	return sqlDBFromConfig(ctx)
}
