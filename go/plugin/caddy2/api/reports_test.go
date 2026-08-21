package api

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/utils_test"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

var router *chi.Mux = nil

// SQL statements to set up test data
// Generate 100 mix entries, from -198 hours (8.25 days) to now.
var setupSql = [...]string{
	`DELETE FROM node`,
	`INSERT INTO node
   	(mac, pid, detect_date, category_id)
    SELECT
        LOWER(CONCAT_WS(
            ':',
            LPAD(HEX(((seq+ 42) >> 40) & 255), 2, '0'),
            LPAD(HEX(((seq+ 42) >> 32) & 255), 2, '0'),
            LPAD(HEX(((seq+ 42) >> 24) & 255), 2, '0'),
            LPAD(HEX(((seq+ 42) >> 16) & 255), 2, '0'),
            LPAD(HEX(((seq+ 42) >> 8) & 255), 2, '0'),
            LPAD(HEX((seq+ 42) & 255), 2, '0')
        )) AS mac,
		 CASE MOD(seq, 2) WHEN 0 THEN 'default' ELSE 'admin' END AS pid,
        DATE_SUB('2025-06-06 00:00:00', INTERVAL (seq - 1) * 2 HOUR) AS detect_date,
		MOD(seq, 4) + 1 AS category_id
      FROM seq_1_to_100;
	`,
}

var cleanupSql = [...]string{
	`DELETE FROM node`,
}

type reportsResponse struct {
	Items []Report `json:"items"`
	ApiResponsePagination
}

type reportResponse struct {
	Item Report `json:"item"`
	ApiResponse
}

type reportOptionsResponse struct {
	ReportOptions
	ApiResponse
}

type reportSearchResponse struct {
	Items []any `json:"items"`
	ApiResponsePagination
}

func TestReportList(t *testing.T) {
	t.Run("Should return multiple reports", func(t *testing.T) {
		var body reportsResponse
		execReq(t, http.MethodGet, "/api/v1.1/reports", nil, http.StatusOK, &body)
		utils_test.IsGT(t, "", len(body.Items), 4)
	})
}

func TestReportGet(t *testing.T) {
	t.Run("Unknown report", func(t *testing.T) {
		var body reportResponse
		execReq(t, http.MethodGet, "/api/v1.1/report/Node::Report::Test::unknown42", nil, http.StatusNotFound, &body)
		utils_test.IsEqInt(t, "", body.Status, 404)
	})
	t.Run("Should exists", func(t *testing.T) {
		var body reportResponse
		execReq(t, http.MethodGet, "/api/v1.1/report/Node::Report::Test::Nothing", nil, http.StatusOK, &body)
		utils_test.IsEqStr(t, "", body.Item.Id, "Node::Report::Test::Nothing")
		t.Run("Should have default values", func(t *testing.T) {
			utils_test.IsEqBool(t, "HasDateRange", sharedutils.IsEnabled(body.Item.HasDateRange), false)
			utils_test.IsEqBool(t, "HasLimit", sharedutils.IsEnabled(body.Item.HasLimit), false)
		})
	})
	t.Run("Should exists an other", func(t *testing.T) {
		var body reportResponse
		execReq(t, http.MethodGet, "/api/v1.1/report/Node::Report::Test::Cursor", nil, http.StatusOK, &body)
		utils_test.IsEqStr(t, "id", body.Item.Id, "Node::Report::Test::Cursor")
		utils_test.IsEqStr(t, "type", body.Item.Type, "sql")
	})
	t.Run("Check report values", func(t *testing.T) {
		var body reportResponse
		execReq(t, http.MethodGet, "/api/v1.1/report/Node::Report::Test::Cursor", nil, http.StatusOK, &body)
		utils_test.IsEqBool(t, "HasDateRange", sharedutils.IsEnabled(body.Item.HasDateRange), false)
		utils_test.IsEqStr(t, "DefaultLimit", body.Item.DefaultLimit, "4")
		utils_test.IsEqStr(t, "CursorType", body.Item.CursorType, "field")
		utils_test.IsEqStr(t, "CursorField", body.Item.CursorField, "mac")
		utils_test.IsEqStr(t, "CursorDefault", body.Item.CursorDefault, "00:00:00:00:00:00")
		utils_test.IsEqStr(t, "Bindings", body.Item.Bindings, "cursor,limit")
	})
}

func TestReportOptions(t *testing.T) {
	t.Run("Should respond to OPTIONS", func(t *testing.T) {
		var body reportOptionsResponse
		execReq(t, http.MethodOptions, "/api/v1.1/report/Node::Report::Test::Nothing", nil, http.StatusOK, &body)
	})
	t.Run("Should respond to OPTIONS not found", func(t *testing.T) {
		var body reportOptionsResponse
		execReq(t, http.MethodOptions, "/api/v1.1/report/Node::Report::Test::Nothin", nil, http.StatusNotFound, &body)
	})
	t.Run("Check default values", func(t *testing.T) {
		var body reportOptionsResponse
		execReq(t, http.MethodOptions, "/api/v1.1/report/Node::Report::Test::Nothing", nil, http.StatusOK, &body)
		utils_test.IsEqStr(t, "Id", body.ReportMeta.Id, "Node::Report::Test::Nothing")
		utils_test.IsEqBool(t, "HasDateRange", body.ReportMeta.HasDateRange, false)
		utils_test.IsEqBool(t, "HasLimit", body.ReportMeta.HasLimit, false)
		utils_test.IsEqBool(t, "HasCursor", body.ReportMeta.HasCursor, false)
	})
	t.Run("Check values", func(t *testing.T) {
		var body reportOptionsResponse
		execReq(t, http.MethodOptions, "/api/v1.1/report/Node::Report::Test::Cursor", nil, http.StatusOK, &body)
		utils_test.IsEqStr(t, "Id", body.ReportMeta.Id, "Node::Report::Test::Cursor")
		utils_test.IsEqStr(t, "DefaultLimit", body.ReportMeta.DefaultLimit, "4")
		utils_test.IsEqBool(t, "HasDateRange", body.ReportMeta.HasDateRange, false)
		utils_test.IsEqBool(t, "HasLimit", body.ReportMeta.HasLimit, true)
		utils_test.IsEqBool(t, "HasCursor", body.ReportMeta.HasCursor, true)
	})
}

func TestReporSearch(t *testing.T) {
	t.Run("Check default limit 1", func(t *testing.T) {
		payload := ReportSearchParams{Limit: 10, Cursor: 0}
		var body reportSearchResponse
		execReq(t, http.MethodPost, "/api/v1.1/report/Node::Report::Test::Nothing/search", &payload, http.StatusOK, &body)
		utils_test.IsEqInt(t, "Items", len(body.Items), 1)
	})
	t.Run("Check limit", func(t *testing.T) {
		limitExpected := 5
		payload := ReportSearchParams{Limit: limitExpected}
		var body reportSearchResponse
		execReq(t, http.MethodPost, "/api/v1.1/report/Node::Report::Test::Limit/search", &payload, http.StatusOK, &body)
		utils_test.IsEqInt(t, "Items", len(body.Items), limitExpected)
	})
	t.Run("Check cursor field", func(t *testing.T) {
		limitExpected := 3
		payload := ReportSearchParams{Limit: limitExpected, Cursor: "00:00:00:00:00:01"}
		var body reportSearchResponse
		execReq(t, http.MethodPost, "/api/v1.1/report/Node::Report::Test::Cursor/search", &payload, http.StatusOK, &body)
		utils_test.IsEqInt(t, "Items", len(body.Items), limitExpected)
		firstItem := body.Items[0].(map[string]any)
		mac := firstItem["mac"].(string)
		utils_test.IsEqStr(t, "firstItem", mac, "00:00:00:00:00:2b")
		lastItem := body.Items[limitExpected-1].(map[string]any)
		mac = lastItem["mac"].(string)
		utils_test.IsEqStr(t, "lastItem", mac, "00:00:00:00:00:2d")
	})
	t.Run("Check cursor field prev/next", func(t *testing.T) {
		limitExpected := 5
		payload := ReportSearchParams{Limit: limitExpected, Cursor: "00:00:00:00:00:2c"}
		var body reportSearchResponse
		execReq(t, http.MethodPost, "/api/v1.1/report/Node::Report::Test::Cursor/search", &payload, http.StatusOK, &body)
		utils_test.IsEqInt(t, "Items", len(body.Items), limitExpected)
		firstItem := body.Items[0].(map[string]any)
		mac := firstItem["mac"].(string)
		utils_test.IsEqStr(t, "firstItem", mac, "00:00:00:00:00:2c")
		lastItem := body.Items[limitExpected-1].(map[string]any)
		mac = lastItem["mac"].(string)
		utils_test.IsEqStr(t, "lastItem", mac, "00:00:00:00:00:30")
		utils_test.IsEqStr(t, "PrevCursor", body.PrevCursor.(string), "00:00:00:00:00:2c")
		utils_test.IsEqStr(t, "NextCursor", body.NextCursor.(string), "00:00:00:00:00:31")
	})
	t.Run("Check cursor field out of bound", func(t *testing.T) {
		limitExpected := 5
		payload := ReportSearchParams{Limit: limitExpected, Cursor: "ff:ff:ff:ff:ff:ff"}
		var body reportSearchResponse
		execReq(t, http.MethodPost, "/api/v1.1/report/Node::Report::Test::Cursor/search", &payload, http.StatusOK, &body)
		utils_test.IsEqInt(t, "Items", len(body.Items), 0)
		utils_test.IsEqStr(t, "PrevCursor", body.PrevCursor.(string), "00:00:00:00:00:00")
		utils_test.IsNil(t, "NextCursor", body.NextCursor)
	})
	t.Run("Check cursor empty date range", func(t *testing.T) {
		var body reportSearchResponse
		payload := ReportSearchParams{Limit: 5, Cursor: "ff:ff:ff:ff:ff:ff", StartDate: "", EndDate: ""}
		execReq(t, http.MethodPost, "/api/v1.1/report/Node::Report::Test::DateRange/search", &payload, http.StatusBadRequest, &body)
	})
	t.Run("Check cursor bad date range", func(t *testing.T) {
		var body reportSearchResponse
		payload := ReportSearchParams{Limit: 5, Cursor: "ff:ff:ff:ff:ff:ff", StartDate: "123", EndDate: "123"}
		execReq(t, http.MethodPost, "/api/v1.1/report/Node::Report::Test::DateRange/search", &payload, http.StatusBadRequest, &body)
	})
	t.Run("Check cursor date range", func(t *testing.T) {
		var body reportSearchResponse
		limitExpected := 5
		payload := ReportSearchParams{Limit: limitExpected, Cursor: "00:00:00:00:00:01", StartDate: "1970-01-01 00:00:00", EndDate: "2100-01-01 00:00:00"}
		execReq(t, http.MethodPost, "/api/v1.1/report/Node::Report::Test::DateRange/search", &payload, http.StatusOK, &body)
		utils_test.IsEqInt(t, "Items", len(body.Items), limitExpected)
		utils_test.IsEqStr(t, "PrevCursor", body.PrevCursor.(string), "00:00:00:00:00:2b")
		utils_test.IsEqStr(t, "NextCursor", body.NextCursor.(string), "00:00:00:00:00:30")
	})
	t.Run("Check cursor multi_field", func(t *testing.T) {
		var body reportSearchResponse
		limitExpected := 4
		payload := ReportSearchParams{Limit: limitExpected, Cursor: []string{"00:00:00:00:00:01", "1970-01-01 00:00:00"}}
		execReq(t, http.MethodPost, "/api/v1.1/report/Node::Report::Test::MultiField/search", &payload, http.StatusOK, &body)
		utils_test.IsEqInt(t, "Items", len(body.Items), limitExpected)
		utils_test.IsEqArr(t, "PrevCursor", body.PrevCursor.([]any), []any{"00:00:00:00:00:8e", "2025-05-28T18:00:00Z"})
		utils_test.IsEqArr(t, "NextCursor", body.NextCursor.([]any), []any{"00:00:00:00:00:8a", "2025-05-29T02:00:00Z"})
	})
	t.Run("Check cursor multi_field again", func(t *testing.T) {
		var body reportSearchResponse
		limitExpected := 4
		payload := ReportSearchParams{Limit: limitExpected, Cursor: []string{"00:00:00:00:00:8e", "2025-05-28 18:00:00"}}
		execReq(t, http.MethodPost, "/api/v1.1/report/Node::Report::Test::MultiField/search", &payload, http.StatusOK, &body)
		utils_test.IsEqInt(t, "Items", len(body.Items), limitExpected)
		utils_test.IsEqArr(t, "PrevCursor", body.PrevCursor.([]any), []any{"00:00:00:00:00:8e", "2025-05-28T18:00:00Z"})
		utils_test.IsEqArr(t, "NextCursor", body.NextCursor.([]any), []any{"00:00:00:00:00:8a", "2025-05-29T02:00:00Z"})
	})
	t.Run("Check cursor multi_field multi type", func(t *testing.T) {
		// json number are float64 be carefull
		var body reportSearchResponse
		limitExpected := 4
		payload := ReportSearchParams{Limit: limitExpected, Cursor: []any{"00:00:00:00:00:00", 0.0}}
		execReq(t, http.MethodPost, "/api/v1.1/report/Node::Report::Test::CursorMultiType/search", &payload, http.StatusOK, &body)
		utils_test.IsEqInt(t, "Items", len(body.Items), limitExpected)
		utils_test.IsEqArr(t, "PrevCursor", body.PrevCursor.([]any), []any{"00:00:00:00:00:2e", 1.0})
		utils_test.IsEqArr(t, "NextCursor", body.NextCursor.([]any), []any{"00:00:00:00:00:3e", 1.0})
		payload = ReportSearchParams{Limit: limitExpected, Cursor: []any{"00:00:00:00:00:00", "0"}}
		execReq(t, http.MethodPost, "/api/v1.1/report/Node::Report::Test::CursorMultiType/search", &payload, http.StatusOK, &body)
		utils_test.IsEqInt(t, "Items", len(body.Items), limitExpected)
		utils_test.IsEqArr(t, "PrevCursor", body.PrevCursor.([]any), []any{"00:00:00:00:00:2e", 1.0})
		utils_test.IsEqArr(t, "NextCursor", body.NextCursor.([]any), []any{"00:00:00:00:00:3e", 1.0})
	})
	t.Run("Check cursor field unallowed binding", func(t *testing.T) {
		var body reportSearchResponse
		limitExpected := 4
		payload := ReportSearchParams{Limit: limitExpected, Cursor: "00:00:00:00:00:00"}
		execReq(t, http.MethodPost, "/api/v1.1/report/Node::Report::Test::BindingIsAColumn/search", &payload, http.StatusBadRequest, &body)
	})
}

func TestReportIdForPerlApi(t *testing.T) {
	tests := []struct {
		method   string
		path     string
		expected string
	}{
		{http.MethodPost, "/api/v1.1/report/Node::Report::Test/search", "Node::Report::Test"},
		{http.MethodOptions, "/api/v1.1/report/Node::Report::Test", "Node::Report::Test"},
		{http.MethodGet, "/api/v1.1/report/Node::Report::Test/search", ""},
		{http.MethodGet, "/api/v1.1/report/Node::Report::Test", ""},
		{http.MethodPost, "/api/v1.1/report/Node::Report::Test", ""},
		{http.MethodOptions, "/api/v1.1/report/Node::Report::Test/search", ""},
		{http.MethodOptions, "/api/v1.1/reports", ""},
		{http.MethodPost, "/api/v1.1/reports", ""},
		{http.MethodPost, "/api/v1.1/report//search", ""},
		{http.MethodPost, "/api/v1.1/report/Node::Report::Test/foo/search", ""},
		{http.MethodPost, "/api/v1/dynamic_report/Node::Report::Test/search", ""},
	}
	for _, test := range tests {
		utils_test.IsEqStr(
			t,
			test.method+" "+test.path,
			reportIdForPerlApi(test.method, test.path),
			test.expected,
		)
	}
}

func TestMain(m *testing.M) {
	var err error
	router, err = initRouterAndDb()
	if err != nil {
		fmt.Printf("Cannot initialize router and db: %s", err.Error())
		os.Exit(1)
	}
	err = utils_test.RunStatements(setupSql[:])
	if err != nil {
		fmt.Printf("Cannot setup test data: %s", err.Error())
		os.Exit(1)
	}
	code := m.Run()
	err = utils_test.RunStatements(cleanupSql[:])
	if err != nil {
		fmt.Printf("Cannot cleanup test data: %s", err.Error())
		os.Exit(1)
	}
	os.Exit(code)
}

func execReq(t *testing.T, method, url string, payload any, statusExpected int, bodyOut any) {
	buff, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("Cannot marshal payload: %s", err.Error())
	}
	payloadReader := bytes.NewBuffer(buff)
	req := httptest.NewRequest(method, url, payloadReader)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	res := w.Result()
	defer res.Body.Close()
	body, err := io.ReadAll(res.Body)
	if err != nil {
		t.Fatalf("Cannot read body: %s", err.Error())
	}
	if res.StatusCode != statusExpected {
		var errBody ApiResponse
		err = json.Unmarshal(body, &errBody)
		if err != nil {
			fmt.Println(string(body))
			t.Fatalf("Cannot unmarshall: %s", err.Error())
		}
		t.Fatalf("Expected status %d, got %d: %v", statusExpected, res.StatusCode, errBody.Errors)
	}
	err = json.Unmarshal(body, bodyOut)
	if err != nil {
		t.Fatalf("Cannot unmarshall: %s", err.Error())
	}
}

func initRouterAndDb() (*chi.Mux, error) {
	ctx := context.Background()
	DB, err := gorm.Open(mysql.Open(db.ReturnURIFromConfig(ctx)), &gorm.Config{})
	if err != nil {
		return nil, fmt.Errorf("Cannot open db %s", err.Error())
	}
	tmpRouter := chi.NewRouter()
	reportHandler := NewDynamicReport(context.Background(), &DB)
	reportHandler.AddToRouter(tmpRouter)
	return tmpRouter, nil
}
