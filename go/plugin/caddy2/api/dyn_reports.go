package api

import (
	"context"
	"net/http"

	"github.com/julienschmidt/httprouter"
	"gorm.io/gorm"
)

type DynamicReport struct {
	DBP **gorm.DB
	Ctx *context.Context
}

func NewDynamicReport(ctx context.Context, dbp **gorm.DB) *DynamicReport {
	return &DynamicReport{
		DBP: dbp,
		Ctx: &ctx,
	}
}

func (a *DynamicReport) List(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	w.WriteHeader(http.StatusNoContent)
}

func (a *DynamicReport) GetItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	w.WriteHeader(http.StatusNoContent)
}

func (a *DynamicReport) SearchItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	w.WriteHeader(http.StatusNoContent)
}

func (a *DynamicReport) OptionsItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	w.WriteHeader(http.StatusNoContent)
}

func (a *DynamicReport) AddToRouter(r *httprouter.Router) {
	r.GET("/api/v1.2/dynamic_reports", a.List)
	r.GET("/api/v1.2/dynamic_report/:id", a.GetItem)
	r.POST("/api/v1.2/dynamic_report/:id/search", a.SearchItem)
	r.OPTIONS("/api/v1.2/dynamic_report/:id", a.OptionsItem)
}
