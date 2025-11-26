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

// reportSerializer, output
// pfconfigdriver.DynamicReport is used ot read data from backend
// This struct is used to response request. For compatibility purpose,
// all arrays are converted to commad separted strings: [1, 2, 3] => "1,2,3"
// Sql field is converted to array of lines (split sql with "\n" char)
type ReportResponse struct {
	pfconfigdriver.DynamicReport
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

// ReportOptionsColumn, output
type ReportOptionsColumn struct {
	Text     string `json:"text"`
	Name     string `json:"name"`
	IsPerson bool   `json:"is_person"`
	IsNode   bool   `json:"is_node"`
	IsRole   bool   `json:"is_role"`
	IsCursor bool   `json:"is_cursor"`
}

// ReportOptionsResponse, output
type ReportOptionsResponse struct {
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
		Columns          []ReportOptionsColumn `json:"columns"`
		Charts           []string              `json:"charts"`
	} `json:"report_meta"`
}

// ReportSearchParams, input
type ReportSearchParams struct {
	Limit     int    `json:"limit,omitempty"`
	StartDate string `json:"start_date,omitempty"`
	EndDate   string `json:"end_date,omitempty"`
	Cursor    any    `json:"cursor,omitempty"`
}

type reportSearchFieldQuery = map[string]any

var cachedReportConfig = pfconfigdriver.NewCachedValue(reflect.TypeOf(pfconfigdriver.DynamicReports{}))

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

func (a *DynamicReport) AddToRouter(r *httprouter.Router) {
	r.GET("/api/v1.2/dynamic_reports", a.List)
	r.GET("/api/v1.2/dynamic_report/:id", a.GetItem)
	r.OPTIONS("/api/v1.2/dynamic_report/:id", a.OptionsItem)
	r.POST("/api/v1.2/dynamic_report/:id/search", a.SearchItem)
}

func (a *DynamicReport) List(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body wip.ApiBody
	reports, err := getReports(r)
	if err != nil {
		body.QuickError(w, http.StatusInternalServerError, "Cannot get reports from cache: "+err.Error())
		return
	}
	reportsAsArray := slices.Collect(maps.Values(reports))
	respReports := make([]ReportResponse, 0, len(reportsAsArray))
	for k := range reportsAsArray {
		tmpReport := ReportResponse{}
		reportSerializer(&tmpReport, &reportsAsArray[k])
		respReports = append(respReports, tmpReport)
	}
	body.ResponseItems(w, http.StatusOK, respReports)
}

func (a *DynamicReport) GetItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body wip.ApiBody
	inReport, shouldReturn := getReportById(w, r, p, &body)
	if shouldReturn {
		return
	}
	outReport := ReportResponse{}
	reportSerializer(&outReport, inReport)
	body.ResponseItem(w, http.StatusOK, outReport)
}

func (a *DynamicReport) OptionsItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body wip.ApiBody
	inReport, shouldReturn := getReportById(w, r, p, &body)
	if shouldReturn {
		return
	}
	var options ReportOptionsResponse
	fillOptionsStruct(a, &options, inReport)
	body.ResponseRaw(w, http.StatusOK, &options)
}

func (a *DynamicReport) SearchItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	var body wip.ApiBody
	inReport, shouldReturn := getReportById(w, r, p, &body)
	if shouldReturn {
		return
	}
	defer r.Body.Close()
	var payload ReportSearchParams
	err := json.NewDecoder(r.Body).Decode(&payload)
	if err != nil {
		body.QuickError(w, http.StatusBadRequest, "cannot parse request: "+err.Error())
		return
	}
	// Valide the payload and store binding data into a map for later use
	options := make(map[string]any)
	validationErrors := validateSearchPayload(options, payload, inReport)
	if len(validationErrors) > 0 {
		for _, e := range validationErrors {
			body.AddMessageError(e.Error())
		}
		body.ResponseError(w, http.StatusBadRequest)
		return
	}
	// Create the binding list in order. A binding can appear multiple time at different positions
	injectedBindings := make([]any, 0)
	bindingError := false
	for _, binding := range inReport.Bindings {
		e, ok := options[binding]
		if !ok {
			bindingError = true
			body.AddMessageError("missing binding: " + binding)
			continue
		}
		injectedBindings = append(injectedBindings, e)
	}
	if bindingError {
		body.ResponseError(w, http.StatusInternalServerError)
		return
	}
	cleanedSql := cleanSql(inReport.Sql)
	items, err := executeSearchQuery(a.DBP, cleanedSql, injectedBindings)
	if err != nil {
		body.QuickError(w, http.StatusInternalServerError, "cannot execute search query: "+err.Error())
		return
	}
	if err := paginateQuery(&body, &items, options); err != nil {
		body.QuickError(w, http.StatusBadRequest, "cannot paginate results: "+err.Error())
		return
	}
	body.ResponseItems(w, http.StatusOK, items)
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

func fillOptionsColumns(columns *[]ReportOptionsColumn, report *pfconfigdriver.DynamicReport) {
	// Match TEXT in: foo [as ][\]"TEXT[\]"
	// All possible format: foo as \"bar\" | foo "bar" | "foo \"bar\"" | "bar"
	regexp := regexp.MustCompile(`^\S+\s+(?:as\s)?\\?\"(.+)\\?\"`)
	for _, v := range report.Columns {
		var value string
		newColumn := ReportOptionsColumn{}
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

func fillOptionsStruct(a *DynamicReport, options *ReportOptionsResponse, report *pfconfigdriver.DynamicReport) {
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
	options.ReportMeta.Columns = []ReportOptionsColumn{} // force json [] instead of null
	fillOptionsColumns(&options.ReportMeta.Columns, report)
}

func validateSearchPayload(opts map[string]any, payload ReportSearchParams, report *pfconfigdriver.DynamicReport) []error {
	opts["cursor_type"] = report.CursorType
	opts["cursor_default"] = report.CursorDefault
	opts["cursor_field"] = nil
	errLst := make([]error, 0)
	if len(report.Bindings) == 0 {
		return errLst
	}
	cursorRe := regexp.MustCompile(`^cursor\.(\d+)$`) // to match multi_field cursor.x
	// payload.Cursor is a string, each value ar comma separted: 'cursor1,cursor2,...'
	// convert all to []string
	optsCursor := make([]string, 0)
	reqCursor := make([]string, 0)
	if payload.Cursor != nil && len(payload.Cursor.(string)) > 0 {
		reqCursor = append(reqCursor, strings.Split(payload.Cursor.(string), ",")...)
		for i := range reqCursor {
			reqCursor[i] = strings.TrimSpace(reqCursor[i])
		}
	}
	for _, binding := range report.Bindings {
		if _, ok := opts[binding]; ok {
			continue // skip already added cursors
		}
		opts[binding] = nil
		switch binding {
		case "limit":
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
		case "start_date", "end_date":
			dateReg := regexp.MustCompile(`^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$`)
			if binding == "start_date" {
				if len(payload.StartDate) == 0 {
					errLst = append(errLst, errors.New("start_date has an empty value"))
				} else {
					if !dateReg.MatchString(payload.StartDate) {
						errLst = append(errLst, errors.New("start_date has an invalid value"))
					} else {
						opts["start_date"] = payload.StartDate
					}
				}
			} else {
				if len(payload.EndDate) == 0 {
					errLst = append(errLst, errors.New("end_date has an empty value"))
				} else {
					if !dateReg.MatchString(payload.EndDate) {
						errLst = append(errLst, errors.New("start_date has an invalid value"))
					} else {
						opts["end_date"] = payload.EndDate
					}
				}
			}
		case "cursor":
			switch report.CursorType {
			case "offset":
				if len(reqCursor) != 0 {
					opts["cursor"] = reqCursor[0]
				} else {
					opts["cursor"] = "0"
				}
				opts["cursor_field"] = nil // no field since it's an offset
			case "field":
				if len(reqCursor) != 0 {
					opts["cursor"] = reqCursor[0]
				} else {
					opts["cursor"] = report.CursorDefault[0] // contains only on value
				}
				opts["cursor_field"] = report.CursorField[0]
			default:
				errLst = append(errLst, errors.New("cursor_type has invalid value"))
			}
		default: // multi_field cursor.x, or any columns
			if result := cursorRe.FindStringSubmatch(binding); result != nil {
				opts["cursor_field"] = report.CursorField
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

			} else { // any other column binding

			}
		}
	}
	if report.CursorType == "multi_field" {
		if len(optsCursor) > 0 {
			opts["cursor"] = optsCursor
		} else {
			opts["cursor"] = nil
		}
	}
	if sharedutils.IsEnabled(report.HasDateRange) {
		if opts["start_date"] == nil {
			errLst = append(errLst, errors.New("start_date is required"))
		}
		if opts["end_date"] == nil {
			errLst = append(errLst, errors.New("end_date is required"))
		}
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

func paginateQuery(body *wip.ApiBody, items *[]reportSearchFieldQuery, options map[string]any) error {
	limitElem, ok := options["limit"]
	if !ok {
		return nil
	}
	limit, _ := strconv.Atoi(limitElem.(string))
	currPageCount := len(*items)

	var cursorType string
	if options["cursor_type"] != nil {
		cursorType = options["cursor_type"].(string)
	}
	if !(len(cursorType) == 0 || cursorType == "none" || options["cursor"] == nil) {
		if cursorType == "multi_field" {
			cursorFields := options["cursor_field"].([]string)
			prevCursor := make([]any, 0)
			field := (*items)[0]
			for _, fieldName := range cursorFields {
				fieldValue, ok := field[fieldName]
				if !ok {
					return errors.New("cannot find cursor field: " + fieldName)
				}
				prevCursor = append(prevCursor, fieldValue)
			}
			body.PrevCursor = prevCursor
		} else { // take the cursor of the first record
			if currPageCount == 0 {
				if options["cursor_default"] != nil {
					body.PrevCursor = options["cursor_default"].([]string)[0]
				} else if hasLen(options["cursor"]) && getLen(options["cursor"]) != 0 {
					body.PrevCursor = options["cursor"].(string)
				} else {
					body.PrevCursor = options["cursor"]
				}
			} else {
				// fields checked already in prevCursor part
				body.PrevCursor = (*items)[0][options["cursor_field"].(string)]
			}
		}

	} else {
		body.PrevCursor = options["cursor"]
	}
	if currPageCount >= limit {
		limit -= 1
		currPageCount -= 1
		switch options["cursor_type"].(string) {
		case "offset":
			body.NextCursor = body.PrevCursor.(int) + limit
		case "field":
			body.NextCursor = (*items)[limit][options["cursor_field"].(string)]
		case "multi_field":
			cursorFields := options["cursor_field"].([]string)
			nextCursor := make([]any, 0)
			for _, field := range cursorFields {
				nextCursor = append(nextCursor, (*items)[limit][field])
			}
			body.NextCursor = nextCursor
		default:
			body.NextCursor = nil
		}
		*items = (*items)[:currPageCount] // do not return the +1 record fetched
	} else {
		body.NextCursor = nil
	}
	// We don't need it right now
	// body.Count = &currPageCount
	// body.Limit = &limit
	return nil
}

func hasLen(value any) bool {
	switch reflect.TypeOf(value).Kind() {
	case reflect.Array, reflect.Chan, reflect.Map, reflect.Slice, reflect.String:
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

func cleanSql(sql string) string {
	regexp := regexp.MustCompile(`\n\s*`)
	cleanSql := regexp.ReplaceAllString(sql, " ")
	return strings.TrimSpace(cleanSql)
}

func reportSerializer(output *ReportResponse, input *pfconfigdriver.DynamicReport) {
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

func getReports(r *http.Request) (map[string]pfconfigdriver.DynamicReport, error) {
	o, err := cachedReportConfig.Value(r.Context())
	if err != nil {
		return nil, err
	}
	reports := o.(*pfconfigdriver.DynamicReports)
	return reports.Element, nil
}

func getReportById(w http.ResponseWriter, r *http.Request, p httprouter.Params, body *wip.ApiBody) (*pfconfigdriver.DynamicReport, bool) {
	reports, err := getReports(r)
	if err != nil {
		body.QuickError(w, http.StatusInternalServerError, "Cannot get reports from cache: "+err.Error())
		return nil, true
	}
	id := p.ByName("id")
	if len(id) == 0 {
		body.QuickError(w, http.StatusBadRequest, "report id required")
		return nil, true
	}
	inReport, ok := reports[id]
	if !ok {
		body.QuickError(w, http.StatusNotFound, "report not found")
		return nil, true
	}
	return &inReport, false
}
