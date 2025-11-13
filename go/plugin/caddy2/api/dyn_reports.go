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
	"strconv"

	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/wip"
	"github.com/inverse-inc/packetfence/go/util"
	"github.com/julienschmidt/httprouter"
	"gorm.io/gorm"
)

const defaultSearchLimit int = 25

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
		DefaultLimit     string                `json:"default_limit,omitempty"`
		DateLimit        string                `json:"date_limit,omitempty"`
		DefaultStartDate string                `json:"default_start_date,omitempty"`
		DefaultEndDate   string                `json:"default_end_date,omitempty"`
		Columns          []reportOptionsColumn `json:"columns"`
		Charts           []string              `json:"charts"`
		QueryFields      []reportQueryField    `json:"query_fields"`
	} `json:"report_meta"`
}

type reportSearchParams struct {
	Id        string   `json:"id"` // ignore it
	Limit     int      `json:"limit,omitempty"`
	Fields    []string `json:"fields"` // abstract only
	StartDate string   `json:"start_date,omitempty"`
	EndDate   string   `json:"end_date,omitempty"`
	Query     any      `json:"query,omitempty"` // abstract only
	Cursor    []string `json:"cursor,omitempty"`
}

type reportSearchFieldQuery = map[string]any

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

func getReports(r *http.Request) (map[string]pfconfigdriver.Report, error) {
	o, err := CachedReportConfig.Value(r.Context())
	if err != nil {
		return nil, err
	}
	reports := o.(*pfconfigdriver.Reports)
	return reports.Element, nil
}

func (a *DynamicReport) List(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body wip.ApiBody
	reports, err := getReports(r)
	if err != nil {
		body.ReplyError(w, http.StatusInternalServerError, wip.ApiError{Message: "Cannot get reports from cache: " + err.Error()})
		return
	}
	reportsAsArray := slices.Collect(maps.Values(reports))
	body.ResponseItems(w, http.StatusOK, reportsAsArray)
}

func (a *DynamicReport) GetItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body wip.ApiBody
	reports, err := getReports(r)
	if err != nil {
		body.ReplyError(w, http.StatusInternalServerError, wip.ApiError{Message: "Cannot get reports from cache: " + err.Error()})
		return
	}
	id := p.ByName("id")
	if len(id) == 0 {
		body.ReplyError(w, http.StatusBadRequest, wip.ApiError{Message: "report id required"})
		return
	}
	item, ok := reports[id]
	if !ok {
		body.ReplyError(w, http.StatusNotFound, wip.ApiError{Message: "report not found"})
		return
	}
	body.ResponseItem(w, http.StatusOK, item)
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

func fillOptionsColumns(columns *[]reportOptionsColumn, report *pfconfigdriver.Report) {
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

func fillOptionsStruct(a *DynamicReport, options *reportOptionsResponse, report *pfconfigdriver.Report) {
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
	defaultStartDate, defaultEndDate := "", "" // empty string won't appear in json response
	if sharedutils.IsEnabled(report.HasDateRange) {
		defaultStartDate, defaultEndDate = getDefaultDateRange(a, report.DateLimit)
	}
	options.ReportMeta.DefaultStartDate = defaultStartDate
	options.ReportMeta.DefaultEndDate = defaultEndDate
	options.ReportMeta.Columns = []reportOptionsColumn{} // force json [] instead of null
	fillOptionsColumns(&options.ReportMeta.Columns, report)
}

func (a *DynamicReport) OptionsItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body wip.ApiBody
	id := p.ByName("id")
	reports, err := getReports(r)
	if err != nil {
		body.ReplyError(w, http.StatusInternalServerError, wip.ApiError{Message: "Cannot get reports from cache: " + err.Error()})
		return
	}
	report, ok := reports[id]
	if !ok {
		body.ReplyError(w, http.StatusNotFound, wip.ApiError{Message: "Report not found"})
		return
	}
	var options reportOptionsResponse
	fillOptionsStruct(a, &options, &report)
	body.ResponseRaw(w, http.StatusOK, &options)
}

func validateSearchPayload(opts map[string]string, payload reportSearchParams, report *pfconfigdriver.Report) []error {
	errLst := make([]error, 0, 8)
	if slices.Contains(report.Bindings, "limit") {
		var tmp string
		if payload.Limit != 0 {
			tmp = strconv.Itoa(payload.Limit + 1)
		} else if len(report.DefaultLimit) != 0 {
			tmp = report.DefaultLimit
		} else {
			tmp = strconv.Itoa(defaultSearchLimit)
		}
		opts["limit"] = tmp // contains +1 to get the cursor of the next page
	}
	if sharedutils.IsEnabled(report.HasDateRange) {
		if slices.Contains(report.Bindings, "start_date") {
			if len(payload.StartDate) == 0 {
				errLst = append(errLst, errors.New("start_date has an invalid value"))
			} else {
				opts["start_data"] = payload.StartDate
			}
		} else {
			errLst = append(errLst, errors.New("start_date is required"))
		}
		if slices.Contains(report.Bindings, "end_date") {
			if len(payload.EndDate) == 0 {
				errLst = append(errLst, errors.New("end_date has an invalid value"))
			} else {
				opts["end_date"] = payload.EndDate
			}
		} else {
			errLst = append(errLst, errors.New("end_date is required"))
		}
	} // else ignore even if start_date and end_date in query
	switch report.CursorType {
	case "offset":
		if slices.Contains(report.Bindings, "cursor") {
			if len(payload.Cursor) != 0 {
				opts["cursor"] = payload.Cursor[0] // contains only one value
			} else {
				opts["cursor"] = "0"
			}
		}
	case "field":
		if slices.Contains(report.Bindings, "cursor") {
			if len(payload.Cursor) != 0 {
				opts["cursor"] = payload.Cursor[0] // contains only one value
			} else {
				opts["cursor"] = report.CursorDefault[0] // containes only on value
			}
		}
	case "multi_field":
		cursorRe := regexp.MustCompile(`^cursor\.(\d+)$`)
		for _, binding := range report.Bindings {
			if _, ok := opts[binding]; ok {
				continue // skip already added cursors
			}
			if result := cursorRe.FindStringSubmatch(binding); result != nil {
				index, _ := strconv.Atoi(result[1])
				if len(payload.Cursor) >= index+1 {
					opts[binding] = payload.Cursor[index]
				} else {
					opts[binding] = report.CursorDefault[index]
				}
			}
		}
	default: // nothing to do, should not happens
	}
	return errLst
}

func executeSearchQuery(db **gorm.DB, sql string, bindings []any) ([]reportSearchFieldQuery, error) {
	regexp := regexp.MustCompile(`\\n\s*`)
	cleanSql := regexp.ReplaceAllString(sql, " ")
	rows, err := (*db).Raw(cleanSql, bindings...).Rows()
	if err != nil {
		return nil, errors.New("Cannot execute sql: " + err.Error())
	}
	defer rows.Close()
	items := []reportSearchFieldQuery{}
	for rows.Next() {
		var tmp reportSearchFieldQuery
		err = (*db).ScanRows(rows, &tmp)
		if err != nil {
			return nil, errors.New("Cannot read data: " + err.Error())
		}
		items = append(items, tmp)
	}
	return items, nil
}

func (a *DynamicReport) SearchItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body wip.ApiBody
	id := p.ByName("id")
	reports, err := getReports(r)
	if err != nil {
		body.ReplyError(w, http.StatusInternalServerError, wip.ApiError{Message: "Cannot get reports from cache: " + err.Error()})
		return
	}
	report, ok := reports[id]
	if !ok {
		body.ReplyError(w, http.StatusNotFound, wip.ApiError{Message: "report not found"})
		return
	}
	defer r.Body.Close()
	var payload reportSearchParams
	err = json.NewDecoder(r.Body).Decode(&payload)
	if err != nil {
		body.ReplyError(w, http.StatusBadRequest, wip.ApiError{Message: "cannot parse request: " + err.Error()})
		return
	}
	// Valide the payload and store binding data into a map for later use
	options := make(map[string]string)
	validationErrors := validateSearchPayload(options, payload, &report)
	if len(validationErrors) > 0 {
		for _, e := range validationErrors {
			body.AddError(wip.ApiError{Message: e.Error()})
		}
		body.Error(w, http.StatusBadRequest)
		return
	}
	// Create the binding list in order. A binding can appear multiple time at different positions
	injectedBindings := make([]any, 0)
	bindingError := false
	for _, binding := range report.Bindings {
		e, ok := options[binding]
		if !ok {
			bindingError = true
			body.AddError(wip.ApiError{Message: "missing binding: " + binding})
			continue
		}
		injectedBindings = append(injectedBindings, e)
	}
	if bindingError {
		body.Error(w, http.StatusInternalServerError)
		return
	}
	items, err := executeSearchQuery(a.DBP, report.Sql, injectedBindings)
	if err != nil {
		body.ReplyError(w, http.StatusInternalServerError, wip.ApiError{Message: "cannot execute search query: " + err.Error()})
		return
	}
	body.ResponseItems(w, http.StatusOK, items)
}

func (a *DynamicReport) AddToRouter(r *httprouter.Router) {
	r.GET("/api/v1.2/dynamic_reports", a.List)
	r.GET("/api/v1.2/dynamic_report/:id", a.GetItem)
	r.POST("/api/v1.2/dynamic_report/:id/search", a.SearchItem)
	r.OPTIONS("/api/v1.2/dynamic_report/:id", a.OptionsItem)
}
