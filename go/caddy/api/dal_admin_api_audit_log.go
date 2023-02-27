package api

import (
	"context"
	"database/sql"
	"net/http"

	"github.com/inverse-inc/packetfence/go/db"
	"github.com/julienschmidt/httprouter"
)

type AdminApiAuditLog struct {
	Db *sql.DB
}

func NewAdminApiAuditLog() *AdminApiAuditLog {
	db, _ := db.DbFromConfig(context.Background())
	return &AdminApiAuditLog{
		Db: db,
	}
}

func (a *AdminApiAuditLog) List(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
}

func (a *AdminApiAuditLog) Search(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
}

func (a *AdminApiAuditLog) GetItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
}

func (a *AdminApiAuditLog) DeleteItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
}

func (a *AdminApiAuditLog) UpdateItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
}

func (a *AdminApiAuditLog) AddToRouter(r *httprouter.Router) {
	r.GET("/api/v1/admin_api_audit_logs", a.List)
	r.POST("/api/v1/admin_api_audit_logs/search", a.Search)
	r.GET("/api/v1/admin_api_audit_log/:id", a.GetItem)
	r.DELETE("/api/v1/admin_api_audit_log/:id", a.DeleteItem)
	r.PATCH("/api/v1/admin_api_audit_log/:id", a.UpdateItem)
}
