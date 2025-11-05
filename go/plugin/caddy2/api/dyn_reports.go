package api

import (
	"context"
	"encoding/json"
	"errors"
	"maps"
	"net/http"
	"reflect"
	"slices"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/julienschmidt/httprouter"
	"gorm.io/gorm"
)

var CachedReportConfig = pfconfigdriver.NewCachedValue(reflect.TypeOf(pfconfigdriver.Reports{}))

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
	var body RespBody
	o, _ := CachedReportConfig.Value(r.Context())
	if o == nil {
		setError(&body, errors.New("error bla"), http.StatusBadRequest)
	} else {
		reports := o.(*pfconfigdriver.Reports)
		items := slices.Collect(maps.Values(reports.Element))
		body.Items = items
		body.Status = http.StatusOK
	}
	outputResult(w, body)
}

func (a *DynamicReport) GetItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body RespBody
	id := p.ByName("id")
	o, _ := CachedReportConfig.Value(r.Context())
	reports := o.(*pfconfigdriver.Reports)
	item, ok := reports.Element[id]
	if !ok {
		setError(&body, errors.New("report not found"), http.StatusNotFound)
		outputResult(w, body)
		return
	}
	body.Item = item
	body.Status = http.StatusOK
	outputResult(w, body)
}

func (a *DynamicReport) SearchItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	w.WriteHeader(http.StatusNoContent)
}

type reportOptionsResponse struct {
	ReportMeta struct {
		Id           string `json:"id"`
		HasCursor    bool   `json:"has_cursor"`
		HasLimit     bool   `json:"has_limit"`
		HasDateRange bool   `json:"has_date_range"`
		DefaultLimit string `json:"default_limit"`
		DateLimit    string `json:"date_limit"`
	} `json:"report_meta"`
	Status int `json:"status"`
}

func fillOptionsStruct(options *reportOptionsResponse, report *pfconfigdriver.ReportOptions) error {
	options.ReportMeta.Id = report.Id
	options.ReportMeta.HasCursor = true
	options.ReportMeta.HasLimit = true
	options.ReportMeta.HasDateRange = true
	options.ReportMeta.DefaultLimit = "25"
	options.ReportMeta.DateLimit = "24h"
	return nil
}

func (a *DynamicReport) OptionsItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body RespBody
	o, _ := CachedReportConfig.Value(r.Context())
	reports := o.(*pfconfigdriver.Reports)
	id := p.ByName("id")
	report, ok := reports.Element[id]
	if !ok {
		setError(&body, errors.New("report not found"), http.StatusNotFound)
		outputResult(w, body)
		return
	}
	options := reportOptionsResponse{Status: http.StatusOK}
	fillOptionsStruct(&options, &report)
	data, err := json.Marshal(&options)
	if err != nil {
		setError(&body, err, http.StatusInternalServerError)
		outputResult(w, body)
		return
	}
	// Do not use outputResult, since fields are at root, not under "item"
	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	w.WriteHeader(options.Status)
	w.Write(data)
}

func (a *DynamicReport) AddToRouter(r *httprouter.Router) {
	r.GET("/api/v1.2/dynamic_reports", a.List)
	r.GET("/api/v1.2/dynamic_report/:id", a.GetItem)
	r.POST("/api/v1.2/dynamic_report/:id/search", a.SearchItem)
	r.OPTIONS("/api/v1.2/dynamic_report/:id", a.OptionsItem)
}
