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
	"strings"

	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/wip"
	"github.com/inverse-inc/packetfence/go/util"
	"github.com/julienschmidt/httprouter"
	"gorm.io/gorm"
)

const defaultSearchLimit int = 25

// Report struct
// pfconfigdriver.Report is used ot read data from backend
// This struct is used to response request. For compatibility purpose,
// all arrays are converted to commad separted strings: [1, 2, 3] => "1,2,3"
// Sql field is converted to array of lines (split sql with "\n" char)
// output
type report struct {
	pfconfigdriver.Report
	Charts        string   `json:"charts,omitempty"`
	Columns       string   `json:"columns,omitempty"`
	Formatting    string   `json:"formatting,omitempty"`
	PersonFields  string   `json:"person_fields,omitempty"`
	NodeFields    string   `json:"node_fields,omitempty"`
	RoleFields    string   `json:"role_fields,omitempty"`
	CursorField   string   `json:"cursor_field,omitempty"`
	CursorDefault string   `json:"cursor_default,omitempty"`
	Bindings      string   `json:"bindings,omitempty"`
	Sql           []string `json:"sql,omitempty"`
}

// output
type reportOptionsColumn struct {
	Text     string `json:"text"`
	Name     string `json:"name"`
	IsPerson bool   `json:"is_person"`
	IsNode   bool   `json:"is_node"`
	IsRole   bool   `json:"is_role"`
	IsCursor bool   `json:"is_cursor"`
}

// output
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
	} `json:"report_meta"`
}

// input
type reportSearchParams struct {
	Limit     int    `json:"limit,omitempty"`
	StartDate string `json:"start_date,omitempty"`
	EndDate   string `json:"end_date,omitempty"`
	Cursor    any    `json:"cursor,omitempty"`
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

func cleanSql(sql string) string {
	regexp := regexp.MustCompile(`\n\s*`)
	cleanSql := regexp.ReplaceAllString(sql, " ")
	return strings.TrimSpace(cleanSql)
}

func parseReportForResponse(output *report, input *pfconfigdriver.Report) {
	output.Id = input.Id
	output.Type = input.Type
	output.Description = input.Description
	output.DefaultLimit = input.DefaultLimit
	output.DateLimit = input.DateLimit
	output.CursorType = input.CursorType
	// if empty string, set to "disabled"
	if sharedutils.IsEnabled(input.HasDateRange) {
		output.HasDateRange = "enabled"
	} else {
		output.HasDateRange = "disabled"
	}
	if sharedutils.IsEnabled(input.HasLimit) {
		output.HasLimit = "enabled"
	} else {
		output.HasLimit = "disabled"
	}
	output.Sql = strings.Split(input.Sql, "\n")
	output.Charts = strings.TrimSpace(strings.Join(input.Charts, ","))
	output.Columns = strings.TrimSpace(strings.Join(input.Columns, ","))
	output.PersonFields = strings.TrimSpace(strings.Join(input.PersonFields, ","))
	output.NodeFields = strings.TrimSpace(strings.Join(input.NodeFields, ","))
	output.RoleFields = strings.TrimSpace(strings.Join(input.RoleFields, ","))
	output.CursorField = strings.TrimSpace(strings.Join(input.CursorField, ","))
	output.CursorDefault = strings.TrimSpace(strings.Join(input.CursorDefault, ","))
	output.Bindings = strings.TrimSpace(strings.Join(input.Bindings, ","))
	for _, format := range input.Formatting {
		if len(output.Formatting) > 0 {
			output.Formatting += ","
		}
		output.Formatting += format.Field + ":" + format.Format
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
		body.FastError(w, http.StatusInternalServerError, wip.ApiError{Message: "Cannot get reports from cache: " + err.Error()})
		return
	}
	reportsAsArray := slices.Collect(maps.Values(reports))
	respReports := make([]report, len(reportsAsArray))
	for k := range reportsAsArray {
		tmpReport := report{}
		parseReportForResponse(&tmpReport, &reportsAsArray[k])
		respReports = append(respReports, tmpReport)
	}
	body.ResponseItems(w, http.StatusOK, respReports)
}

// swagger:operation GET /api/demo Demo GetDemo
//
// # Demo
//
// ---
// responses:
//
//	"200":
//	  description: demo
func (a *DynamicReport) GetItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body wip.ApiBody
	reports, err := getReports(r)
	if err != nil {
		body.FastError(w, http.StatusInternalServerError, wip.ApiError{Message: "Cannot get reports from cache: " + err.Error()})
		return
	}
	id := p.ByName("id")
	if len(id) == 0 {
		body.FastError(w, http.StatusBadRequest, wip.ApiError{Message: "report id required"})
		return
	}
	item, ok := reports[id]
	if !ok {
		body.FastError(w, http.StatusNotFound, wip.ApiError{Message: "report not found"})
		return
	}
	tmpReport := report{}
	parseReportForResponse(&tmpReport, &item)
	body.ResponseItem(w, http.StatusOK, tmpReport)
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
	options.ReportMeta.Charts = []string{} // force json [] instead of null
	options.ReportMeta.Charts = append(options.ReportMeta.Charts, report.Charts...)
	options.ReportMeta.HasLimit = sharedutils.IsEnabled(report.HasLimit)
	options.ReportMeta.HasDateRange = sharedutils.IsEnabled(report.HasDateRange)
	if len(report.DefaultLimit) == 0 {
		options.ReportMeta.DefaultLimit = strconv.Itoa(defaultSearchLimit)
	} else {
		options.ReportMeta.DefaultLimit = report.DefaultLimit
	}
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
		body.FastError(w, http.StatusInternalServerError, wip.ApiError{Message: "Cannot get reports from cache: " + err.Error()})
		return
	}
	report, ok := reports[id]
	if !ok {
		body.FastError(w, http.StatusNotFound, wip.ApiError{Message: "Report not found"})
		return
	}
	var options reportOptionsResponse
	fillOptionsStruct(a, &options, &report)
	body.ResponseRaw(w, http.StatusOK, &options)
}

func validateSearchPayload(opts map[string]any, payload reportSearchParams, report *pfconfigdriver.Report) []error {
	errLst := make([]error, 0)
	if slices.Contains(report.Bindings, "limit") {
		var tmp string
		if sharedutils.IsEnabled(report.HasLimit) && payload.Limit != 0 {
			tmp = strconv.Itoa(payload.Limit + 1)
		} else if len(report.DefaultLimit) != 0 {
			defaultLimitInt, err := strconv.Atoi(report.DefaultLimit)
			if err != nil {
				errLst = append(errLst, errors.New("Bad defaultLimit value: "+err.Error()))
			} else {
				tmp = strconv.Itoa(defaultLimitInt + 1)
			}
		} else {
			tmp = strconv.Itoa(defaultSearchLimit + 1)
		}
		opts["limit"] = tmp // contains +1 to get the cursor of the next page
	}
	if sharedutils.IsEnabled(report.HasDateRange) {
		if slices.Contains(report.Bindings, "start_date") {
			if len(payload.StartDate) == 0 {
				errLst = append(errLst, errors.New("start_date has an invalid value"))
			} else {
				opts["start_date"] = payload.StartDate
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
	opts["cursor_type"] = report.CursorType
	opts["cursor_default"] = report.CursorDefault
	// payload.Cursor can be int/string or []int/[]string
	// convert all to []any, convert int/string to string
	optsCursor := make([]string, 0)
	reqCursor := make([]any, 0)
	if payload.Cursor != nil && hasLen(payload.Cursor) && getLen(payload.Cursor) != 0 {
		if report.CursorType == "multi_field" {
			reqCursor = payload.Cursor.([]any)
		} else {
			reqCursor = append(reqCursor, payload.Cursor)
		}
	}
	switch report.CursorType {
	case "offset":
		// always int
		if slices.Contains(report.Bindings, "cursor") {
			if len(reqCursor) != 0 {
				optsCursor = append(optsCursor, strconv.Itoa(reqCursor[0].(int)))
			} else {
				optsCursor = append(optsCursor, "0")
			}
			opts["cursor_field"] = report.CursorField[0]
		}
	case "field":
		// int or string
		if slices.Contains(report.Bindings, "cursor") {
			if len(reqCursor) != 0 {
				switch tmp := reqCursor[0].(type) {
				case int:
					optsCursor = append(optsCursor, strconv.Itoa(tmp))
				case float32, float64:
					optsCursor = append(optsCursor, strconv.FormatFloat(tmp.(float64), 'f', 8, 64))
				case string:
					optsCursor = append(optsCursor, tmp)
				default:
				}
			} else {
				optsCursor = append(optsCursor, report.CursorDefault[0]) // contains only on value
			}
			opts["cursor_field"] = report.CursorField[0]
		}
	case "multi_field":
		opts["cursor_field"] = make([]any, 0)
		cursorRe := regexp.MustCompile(`^cursor\.(\d+)$`)
		for _, binding := range report.Bindings {
			if _, ok := opts[binding]; ok {
				continue // skip already added cursors
			}
			if result := cursorRe.FindStringSubmatch(binding); result != nil {
				index, _ := strconv.Atoi(result[1])
				if len(reqCursor) > index { // cursor.3 requires 4 cursor specified
					opts[binding] = reqCursor[index]
				} else {
					if len(report.CursorDefault) > index {
						opts[binding] = report.CursorDefault[index]
					} else {
						errLst = append(errLst, errors.New("Bad cursor: "+binding))
						continue
					}
				}
				optsCursor = append(optsCursor, opts[binding].(string))
				opts["cursor_field"] = append(opts["cursor_field"].([]any), report.CursorField[index])
			}
		}
	default: // nothing to do, should not happens
	}
	if len(optsCursor) > 0 {
		opts["cursor"] = optsCursor
	} else {
		opts["cursor"] = nil
	}
	return errLst
}

func executeSearchQuery(db **gorm.DB, sql string, bindings []any) ([]reportSearchFieldQuery, error) {
	rows, err := (*db).Raw(sql, bindings...).Rows()
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
		body.FastError(w, http.StatusInternalServerError, wip.ApiError{Message: "Cannot get reports from cache: " + err.Error()})
		return
	}
	report, ok := reports[id]
	if !ok {
		body.FastError(w, http.StatusNotFound, wip.ApiError{Message: "report not found"})
		return
	}
	defer r.Body.Close()
	var payload reportSearchParams
	err = json.NewDecoder(r.Body).Decode(&payload)
	if err != nil {
		body.FastError(w, http.StatusBadRequest, wip.ApiError{Message: "cannot parse request: " + err.Error()})
		return
	}
	// Valide the payload and store binding data into a map for later use
	options := make(map[string]any)
	validationErrors := validateSearchPayload(options, payload, &report)
	if len(validationErrors) > 0 {
		for _, e := range validationErrors {
			body.AddError(wip.ApiError{Message: e.Error()})
		}
		body.ResponseError(w, http.StatusBadRequest)
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
		body.ResponseError(w, http.StatusInternalServerError)
		return
	}
	cleanedSql := cleanSql(report.Sql)
	items, err := executeSearchQuery(a.DBP, cleanedSql, injectedBindings)
	if err != nil {
		body.FastError(w, http.StatusInternalServerError, wip.ApiError{Message: "cannot execute search query: " + err.Error()})
		return
	}
	paginateQuery(&body, &items, options)
	body.ResponseItems(w, http.StatusOK, items)
}

func paginateQuery(body *wip.ApiBody, items *[]reportSearchFieldQuery, options map[string]any) {
	currPageCount := len(*items)
	limit, _ := strconv.Atoi(options["limit"].(string))
	limit = max(limit-1, 0) // handle the case limit=0, even if it should not happen
	body.Limit = &limit
	cursorType := options["cursor_type"].(string)
	if cursorType == "multi_field" {
		body.PrevCursor = options["cursor"]
	} else {
		if options["cursor"] != nil && hasLen(options["cursor"]) && getLen(options["cursor"]) != 0 {
			body.PrevCursor = options["cursor"].([]string)[0]
		} else { // if no cursor specified in the request, take the cursor of the first record
			if currPageCount == 0 {
				body.PrevCursor = options["cursor_default"].([]string)[0]
			} else {
				body.PrevCursor = (*items)[0][options["cursor_field"].(string)]
			}
		}
	}
	if currPageCount > limit {
		currPageCount -= 1
		switch options["cursor_type"].(string) {
		case "offset":
			body.NextCursor = body.PrevCursor.(int) + limit
		case "field":
			body.NextCursor = (*items)[limit][options["cursor_field"].(string)]
		case "multi_field":
			// TODO multi_field: iterate over cursor_field
			body.NextCursor = (*items)[limit][options["cursor_field"].([]string)[0]]
		}
		*items = (*items)[:len(*items)-1] // do not return the +1 record fetched
	} else {
		body.NextCursor = nil
	}
	body.Count = &currPageCount

}

func hasLen(value any) bool {
	switch reflect.TypeOf(value).Kind() {
	case reflect.Array, reflect.Chan, reflect.Map, reflect.Slice, reflect.String:
		return true
	default:
		return false
	}
}

func isArrayOrSlice(value any) bool {
	switch reflect.TypeOf(value).Kind() {
	case reflect.Array, reflect.Slice:
		return true
	default:
		return false
	}
}

// getLen return the len by reflection of value.
// value MUST have beend checked to implement Len
func getLen(value any) int {
	return reflect.ValueOf(value).Len()
}

func (a *DynamicReport) AddToRouter(r *httprouter.Router) {
	r.GET("/api/v1.2/dynamic_reports", a.List)
	r.GET("/api/v1.2/dynamic_report/:id", a.GetItem)
	r.POST("/api/v1.2/dynamic_report/:id/search", a.SearchItem)
	r.OPTIONS("/api/v1.2/dynamic_report/:id", a.OptionsItem)
}
