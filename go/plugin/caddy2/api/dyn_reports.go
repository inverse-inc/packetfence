package api

import (
	"context"
	"encoding/json"
	"errors"
	"maps"
	"net/http"
	"reflect"
	"regexp"
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
	reports := o.(*pfconfigdriver.Reports)
	items := slices.Collect(maps.Values(reports.Element))
	body.Items = items
	body.Status = http.StatusOK
	outputResult(w, body)
}

func (a *DynamicReport) GetItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body RespBody
	id := p.ByName("id")
	o, _ := CachedReportConfig.Value(r.Context())
	reports := o.(*pfconfigdriver.Reports)
	item, ok := reports.Element[id]
	if !ok {
		setError(&body, errors.New("Report not found"), http.StatusNotFound)
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

type reportOptionsColumn struct {
	Text     string `json:"text"`
	Name     string `json:"name"`
	IsPerson bool   `json:"is_person"`
	IsNode   bool   `json:"is_node"`
	IsRole   bool   `json:"is_role"`
	IsCursor bool   `json:"is_cursor"`
}

type reportQueryField struct {
	Name string `json:"name"`
	Text string `json:"text"`
	Type string `json:"type"`
}

type reportOptionsResponse struct {
	ReportMeta struct {
		Id               string                `json:"id"`
		Description      string                `json:"description"`
		HasCursor        bool                  `json:"has_cursor"`
		HasLimit         bool                  `json:"has_limit"`
		HasDateRange     bool                  `json:"has_date_range"`
		DefaultLimit     string                `json:"default_limit"`
		DateLimit        string                `json:"date_limit"`
		DefaultStartDate string                `json:"default_start_date"`
		DefaultEndDate   string                `json:"default_end_date"`
		Columns          []reportOptionsColumn `json:"columns"`
		Charts           []string              `json:"charts"`
		QueryFields      []reportQueryField    `json:"query_fields"`
	} `json:"report_meta"`
	Status int `json:"status"`
}

func getDefaultDateRange() (string, string) {
	startDate := "000-00-00 00:00:00"
	endDate := "999-12-31 23:59:59"
	// execute SQL, INTERVAL == 24h ?
	//"SELECT
	//IFNULL(DATE_FORMAT(DATE_SUB(NOW(), INTERVAL ? SECOND), \"%Y-%m-%d %T\"), '0000-00-00 00:00:00') as default_start_date,
	//DATE_FORMAT(DATE_SUB(NOW(), INTERVAL ? SECOND), \"%Y-%m-%d %T\") as default_end_date"
	return startDate, endDate
}

func fillOptionsColumns(columns *[]reportOptionsColumn, report *pfconfigdriver.ReportOptions) {
	// Match TEXT in: foo [as ][\]"TEXT[\]"
	// All possible format: foo as \"bar\" | foo "bar" | "foo \"bar\"" | "bar"
	regexp := regexp.MustCompile(`^\S+\s+(?:as\s)?\\?\"(.+)\\?\"`)
	for _, v := range report.Columns {
		var value string
		newColumn := reportOptionsColumn{}
		submatches := regexp.FindStringSubmatch(v)
		if submatches == nil {
			if len(v) == 0 { // should not happen ?
				value = ""
			} else { // take the value as it is
				value = v
			}
		} else { // take the extracted value
			value = submatches[1]
		}
		newColumn.Name = value
		newColumn.Text = value
		newColumn.IsCursor = false // harcoded
		newColumn.IsNode = slices.Contains(report.NodeFields, value)
		newColumn.IsRole = slices.Contains(report.RoleFields, value)
		newColumn.IsPerson = slices.Contains(report.PersonFields, value)
		*columns = append(*columns, newColumn)
	}
}

func fillOptionsStruct(options *reportOptionsResponse, report *pfconfigdriver.ReportOptions) {
	// Copy paste values
	options.ReportMeta.Id = report.Id
	options.ReportMeta.Description = report.Description
	options.ReportMeta.QueryFields = []reportQueryField{} // force json [] instead of null
	options.ReportMeta.Charts = []string{}                // force json [] instead of null
	options.ReportMeta.Charts = append(options.ReportMeta.Charts, report.Charts...)
	// Default hardcoded values
	options.ReportMeta.HasCursor = true
	options.ReportMeta.HasLimit = true
	options.ReportMeta.HasDateRange = true
	options.ReportMeta.DefaultLimit = "25"
	options.ReportMeta.DateLimit = "24h" // INTERVAL in the SQL query?
	// Computed values
	defaultStartDate, defaultEndDate := getDefaultDateRange()
	options.ReportMeta.DefaultStartDate = defaultStartDate
	options.ReportMeta.DefaultEndDate = defaultEndDate
	options.ReportMeta.Columns = []reportOptionsColumn{} // force json [] instead of null
	fillOptionsColumns(&options.ReportMeta.Columns, report)
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
