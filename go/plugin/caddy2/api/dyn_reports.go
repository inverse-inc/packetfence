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

	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/util"
	"github.com/julienschmidt/httprouter"
	"gorm.io/gorm"
)

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
		DateLimit        string                `json:"date_limit,omitempty"`
		DefaultStartDate string                `json:"default_start_date,omitempty"`
		DefaultEndDate   string                `json:"default_end_date,omitempty"`
		Columns          []reportOptionsColumn `json:"columns"`
		Charts           []string              `json:"charts"`
		QueryFields      []reportQueryField    `json:"query_fields"`
	} `json:"report_meta"`
	Status int `json:"status"`
}

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

func getReports(r *http.Request) (map[string]pfconfigdriver.ReportOptions, error) {
	o, err := CachedReportConfig.Value(r.Context())
	if err != nil {
		return nil, err
	}
	reports := o.(*pfconfigdriver.Reports)
	return reports.Element, nil
}

func (a *DynamicReport) List(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body RespBody
	reports, err := getReports(r)
	if err != nil {
		setError(&body, errors.New("Cannot get reports from cache: "+err.Error()), http.StatusInternalServerError)
		outputResult(w, body)
		return
	}
	reportsAsArray := slices.Collect(maps.Values(reports))
	body.Items = reportsAsArray
	body.Status = http.StatusOK
	outputResult(w, body)
}

func (a *DynamicReport) GetItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body RespBody
	reports, err := getReports(r)
	if err != nil {
		setError(&body, errors.New("Cannot get reports from cache: "+err.Error()), http.StatusInternalServerError)
		outputResult(w, body)
		return
	}
	id := p.ByName("id")
	if len(id) == 0 {
		setError(&body, errors.New("No report id specified"), http.StatusBadRequest)
		outputResult(w, body)
		return
	}
	item, ok := reports[id]
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

func getDefaultDateRange(a *DynamicReport, interval string) (string, string) {
	startDate := "000-00-00 00:00:00"
	endDate := "999-12-31 23:59:59"
	result := struct {
		Default_start_date string
		Default_end_date   string
	}{}
	duration, err := util.NormalizeTime(interval)
	if err != nil {
		return startDate, endDate
	}
	res := (*a.DBP).Raw(
		`SELECT IFNULL(
			DATE_FORMAT(DATE_SUB(NOW(), INTERVAL ? SECOND), "%Y-%m-%d %T"), '0000-00-00 00:00:00')
				as default_start_date,
			DATE_FORMAT(DATE_SUB(NOW(), INTERVAL ? SECOND), "%Y-%m-%d %T") as default_end_date
		`,
		duration.Seconds(), 0).Scan(&result)
	if res != nil {
		return result.Default_start_date, result.Default_end_date
	} // error ignored
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
		newColumn.IsCursor = slices.Contains(report.CursorField, value)
		newColumn.IsNode = slices.Contains(report.NodeFields, value)
		newColumn.IsRole = slices.Contains(report.RoleFields, value)
		newColumn.IsPerson = slices.Contains(report.PersonFields, value)
		*columns = append(*columns, newColumn)
	}
}

func fillOptionsStruct(a *DynamicReport, options *reportOptionsResponse, report *pfconfigdriver.ReportOptions) {
	// Copy paste values
	options.ReportMeta.Id = report.Id
	options.ReportMeta.Description = report.Description
	options.ReportMeta.QueryFields = []reportQueryField{} // force json [] instead of null
	options.ReportMeta.Charts = []string{}                // force json [] instead of null
	options.ReportMeta.Charts = append(options.ReportMeta.Charts, report.Charts...)
	options.ReportMeta.HasLimit = sharedutils.IsEnabled(report.HasLimit)
	options.ReportMeta.HasDateRange = sharedutils.IsEnabled(report.HasDateRange)
	options.ReportMeta.DefaultLimit = report.DefaultLimit
	options.ReportMeta.DateLimit = report.DateLimit
	// Computed values
	if len(report.CursorType) == 0 || report.CursorType == "none" {
		options.ReportMeta.HasCursor = false
	} else {
		options.ReportMeta.HasCursor = true
	}
	defaultStartDate, defaultEndDate := "", ""
	if sharedutils.IsEnabled(report.HasDateRange) {
		defaultStartDate, defaultEndDate = getDefaultDateRange(a, report.DateLimit)
	}
	options.ReportMeta.DefaultStartDate = defaultStartDate
	options.ReportMeta.DefaultEndDate = defaultEndDate
	options.ReportMeta.Columns = []reportOptionsColumn{} // force json [] instead of null
	fillOptionsColumns(&options.ReportMeta.Columns, report)
}

func (a *DynamicReport) OptionsItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body RespBody
	id := p.ByName("id")
	reports, err := getReports(r)
	if err != nil {
		setError(&body, errors.New("Cannot get reports from cache: "+err.Error()), http.StatusInternalServerError)
		outputResult(w, body)
		return
	}
	report, ok := reports[id]
	if !ok {
		setError(&body, errors.New("Report not found"), http.StatusNotFound)
		outputResult(w, body)
		return
	}
	options := reportOptionsResponse{Status: http.StatusOK}
	fillOptionsStruct(a, &options, &report)
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
