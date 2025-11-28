package api_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"slices"
	"testing"

	"github.com/inverse-inc/go-utils/sharedutils"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/api"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/wip"
	"github.com/inverse-inc/packetfence/go/test_helpers"
	"github.com/julienschmidt/httprouter"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

var router *httprouter.Router = nil

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
	Items []api.ReportResponse `json:"items"`
	wip.ApiSerializerPagination
}

type reportResponse struct {
	Item api.ReportResponse `json:"item"`
	wip.ApiSerializerPagination
}

type reportOptionsResponse struct {
	api.ReportOptionsResponse
	wip.ApiSerializer
}

type reportSearchResponse struct {
	Items []any `json:"items"`
	wip.ApiSerializerPagination
}

func TestGetReports(t *testing.T) {
	t.Run("Should return multiple reports", func(t *testing.T) {
		var body reportsResponse
		execReq(t, http.MethodGet, "/api/v1.2/dynamic_reports", nil, http.StatusOK, &body)
		isGT(t, "", len(body.Items), 4)
	})
}

func TestGetReport(t *testing.T) {
	t.Run("Unknown report", func(t *testing.T) {
		var body reportResponse
		execReq(t, http.MethodGet, "/api/v1.2/dynamic_report/Node::Report::Test::unknown42", nil, http.StatusNotFound, &body)
		isEqInt(t, "", body.Status, 404)
	})
	t.Run("Should exists", func(t *testing.T) {
		var body reportResponse
		execReq(t, http.MethodGet, "/api/v1.2/dynamic_report/Node::Report::Test::Nothing", nil, http.StatusOK, &body)
		isEqStr(t, "", body.Item.Id, "Node::Report::Test::Nothing")
		t.Run("Should have default values", func(t *testing.T) {
			isEqBool(t, "HasDateRange", sharedutils.IsEnabled(body.Item.HasDateRange), false)
			isEqBool(t, "HasLimit", sharedutils.IsEnabled(body.Item.HasLimit), false)
		})
	})
	t.Run("Should exists an other", func(t *testing.T) {
		var body reportResponse
		execReq(t, http.MethodGet, "/api/v1.2/dynamic_report/Node::Report::Test::Cursor", nil, http.StatusOK, &body)
		isEqStr(t, "id", body.Item.Id, "Node::Report::Test::Cursor")
		isEqStr(t, "type", body.Item.Type, "sql")
	})
	t.Run("Check report values", func(t *testing.T) {
		var body reportResponse
		execReq(t, http.MethodGet, "/api/v1.2/dynamic_report/Node::Report::Test::Cursor", nil, http.StatusOK, &body)
		isEqBool(t, "HasDateRange", sharedutils.IsEnabled(body.Item.HasDateRange), false)
		isEqStr(t, "DefaultLimit", body.Item.DefaultLimit, "4")
		isEqStr(t, "CursorType", body.Item.CursorType, "field")
		isEqStr(t, "CursorField", body.Item.CursorField, "mac")
		isEqStr(t, "CursorDefault", body.Item.CursorDefault, "00:00:00:00:00:00")
		isEqStr(t, "Bindings", body.Item.Bindings, "cursor,limit")
	})
}

func TestOptionsReport(t *testing.T) {
	t.Run("Should respond to OPTIONS", func(t *testing.T) {
		var body reportOptionsResponse
		execReq(t, http.MethodOptions, "/api/v1.2/dynamic_report/Node::Report::Test::Nothing", nil, http.StatusOK, &body)
	})
	t.Run("Should respond to OPTIONS not found", func(t *testing.T) {
		var body reportOptionsResponse
		execReq(t, http.MethodOptions, "/api/v1.2/dynamic_report/Node::Report::Test::Nothin", nil, http.StatusNotFound, &body)
	})
	t.Run("Check default values", func(t *testing.T) {
		var body reportOptionsResponse
		execReq(t, http.MethodOptions, "/api/v1.2/dynamic_report/Node::Report::Test::Nothing", nil, http.StatusOK, &body)
		isEqStr(t, "Id", body.ReportMeta.Id, "Node::Report::Test::Nothing")
		isEqBool(t, "HasDateRange", body.ReportMeta.HasDateRange, false)
		isEqBool(t, "HasLimit", body.ReportMeta.HasLimit, false)
		isEqBool(t, "HasCursor", body.ReportMeta.HasCursor, false)
	})
	t.Run("Check values", func(t *testing.T) {
		var body reportOptionsResponse
		execReq(t, http.MethodOptions, "/api/v1.2/dynamic_report/Node::Report::Test::Cursor", nil, http.StatusOK, &body)
		isEqStr(t, "Id", body.ReportMeta.Id, "Node::Report::Test::Cursor")
		isEqStr(t, "DefaultLimit", body.ReportMeta.DefaultLimit, "4")
		isEqBool(t, "HasDateRange", body.ReportMeta.HasDateRange, false)
		isEqBool(t, "HasLimit", body.ReportMeta.HasLimit, true)
		isEqBool(t, "HasCursor", body.ReportMeta.HasCursor, true)
	})
}

func TestSearchReport(t *testing.T) {
	t.Run("Check default limit 1", func(t *testing.T) {
		payload := api.ReportSearchParams{Limit: 10, Cursor: 0}
		var body reportSearchResponse
		execReq(t, http.MethodPost, "/api/v1.2/dynamic_report/Node::Report::Test::Nothing/search", &payload, http.StatusOK, &body)
		isEqInt(t, "Items", len(body.Items), 1)
	})
	t.Run("Check limit", func(t *testing.T) {
		limitExpected := 5
		payload := api.ReportSearchParams{Limit: limitExpected}
		var body reportSearchResponse
		execReq(t, http.MethodPost, "/api/v1.2/dynamic_report/Node::Report::Test::Limit/search", &payload, http.StatusOK, &body)
		isEqInt(t, "Items", len(body.Items), limitExpected)
	})
	t.Run("Check cursor field", func(t *testing.T) {
		limitExpected := 3
		payload := api.ReportSearchParams{Limit: limitExpected, Cursor: "00:00:00:00:00:01"}
		var body reportSearchResponse
		execReq(t, http.MethodPost, "/api/v1.2/dynamic_report/Node::Report::Test::Cursor/search", &payload, http.StatusOK, &body)
		isEqInt(t, "Items", len(body.Items), limitExpected)
		firstItem := body.Items[0].(map[string]any)
		mac := firstItem["mac"].(string)
		isEqStr(t, "firstItem", mac, "00:00:00:00:00:2b")
		lastItem := body.Items[limitExpected-1].(map[string]any)
		mac = lastItem["mac"].(string)
		isEqStr(t, "lastItem", mac, "00:00:00:00:00:2d")
	})
	t.Run("Check cursor field prev/next", func(t *testing.T) {
		limitExpected := 5
		payload := api.ReportSearchParams{Limit: limitExpected, Cursor: "00:00:00:00:00:2c"}
		var body reportSearchResponse
		execReq(t, http.MethodPost, "/api/v1.2/dynamic_report/Node::Report::Test::Cursor/search", &payload, http.StatusOK, &body)
		isEqInt(t, "Items", len(body.Items), limitExpected)
		firstItem := body.Items[0].(map[string]any)
		mac := firstItem["mac"].(string)
		isEqStr(t, "firstItem", mac, "00:00:00:00:00:2c")
		lastItem := body.Items[limitExpected-1].(map[string]any)
		mac = lastItem["mac"].(string)
		isEqStr(t, "lastItem", mac, "00:00:00:00:00:30")
		isEqStr(t, "PrevCursor", body.PrevCursor.(string), "00:00:00:00:00:2c")
		isEqStr(t, "NextCursor", body.NextCursor.(string), "00:00:00:00:00:31")
	})
	t.Run("Check cursor field out of bound", func(t *testing.T) {
		limitExpected := 5
		payload := api.ReportSearchParams{Limit: limitExpected, Cursor: "ff:ff:ff:ff:ff:ff"}
		var body reportSearchResponse
		execReq(t, http.MethodPost, "/api/v1.2/dynamic_report/Node::Report::Test::Cursor/search", &payload, http.StatusOK, &body)
		isEqInt(t, "Items", len(body.Items), 0)
		isEqStr(t, "PrevCursor", body.PrevCursor.(string), "00:00:00:00:00:00")
		isNil(t, "NextCursor", body.NextCursor)
	})
	t.Run("Check cursor empty date range", func(t *testing.T) {
		var body reportSearchResponse
		payload := api.ReportSearchParams{Limit: 5, Cursor: "ff:ff:ff:ff:ff:ff", StartDate: "", EndDate: ""}
		execReq(t, http.MethodPost, "/api/v1.2/dynamic_report/Node::Report::Test::DateRange/search", &payload, http.StatusBadRequest, &body)
	})
	t.Run("Check cursor bad date range", func(t *testing.T) {
		var body reportSearchResponse
		payload := api.ReportSearchParams{Limit: 5, Cursor: "ff:ff:ff:ff:ff:ff", StartDate: "123", EndDate: "123"}
		execReq(t, http.MethodPost, "/api/v1.2/dynamic_report/Node::Report::Test::DateRange/search", &payload, http.StatusBadRequest, &body)
	})
	t.Run("Check cursor date range", func(t *testing.T) {
		var body reportSearchResponse
		limitExpected := 5
		payload := api.ReportSearchParams{Limit: limitExpected, Cursor: "00:00:00:00:00:01", StartDate: "1970-01-01 00:00:00", EndDate: "2100-01-01 00:00:00"}
		execReq(t, http.MethodPost, "/api/v1.2/dynamic_report/Node::Report::Test::DateRange/search", &payload, http.StatusOK, &body)
		isEqInt(t, "Items", len(body.Items), limitExpected)
		isEqStr(t, "PrevCursor", body.PrevCursor.(string), "00:00:00:00:00:2b")
		isEqStr(t, "NextCursor", body.NextCursor.(string), "00:00:00:00:00:30")
	})
	t.Run("Check cursor multi_field", func(t *testing.T) {
		var body reportSearchResponse
		limitExpected := 4
		payload := api.ReportSearchParams{Limit: limitExpected, Cursor: []string{"00:00:00:00:00:01", "1970-01-01 00:00:00"}}
		execReq(t, http.MethodPost, "/api/v1.2/dynamic_report/Node::Report::Test::MultiField/search", &payload, http.StatusOK, &body)
		isEqInt(t, "Items", len(body.Items), limitExpected)
		isEqArr(t, "PrevCursor", body.PrevCursor.([]any), []any{"00:00:00:00:00:8e", "2025-05-28T18:00:00Z"})
		isEqArr(t, "NextCursor", body.NextCursor.([]any), []any{"00:00:00:00:00:8a", "2025-05-29T02:00:00Z"})
	})
	t.Run("Check cursor multi_field again", func(t *testing.T) {
		var body reportSearchResponse
		limitExpected := 4
		payload := api.ReportSearchParams{Limit: limitExpected, Cursor: []string{"00:00:00:00:00:8e", "2025-05-28 18:00:00"}}
		execReq(t, http.MethodPost, "/api/v1.2/dynamic_report/Node::Report::Test::MultiField/search", &payload, http.StatusOK, &body)
		isEqInt(t, "Items", len(body.Items), limitExpected)
		isEqArr(t, "PrevCursor", body.PrevCursor.([]any), []any{"00:00:00:00:00:8e", "2025-05-28T18:00:00Z"})
		isEqArr(t, "NextCursor", body.NextCursor.([]any), []any{"00:00:00:00:00:8a", "2025-05-29T02:00:00Z"})
	})
	t.Run("Check cursor multi_field multi type", func(t *testing.T) {
		// json number are float64 be carefull
		var body reportSearchResponse
		limitExpected := 4
		payload := api.ReportSearchParams{Limit: limitExpected, Cursor: []any{"00:00:00:00:00:00", 0.0}}
		execReq(t, http.MethodPost, "/api/v1.2/dynamic_report/Node::Report::Test::CursorMultiType/search", &payload, http.StatusOK, &body)
		isEqInt(t, "Items", len(body.Items), limitExpected)
		isEqArr(t, "PrevCursor", body.PrevCursor.([]any), []any{"00:00:00:00:00:2e", 1.0})
		isEqArr(t, "NextCursor", body.NextCursor.([]any), []any{"00:00:00:00:00:3e", 1.0})
		payload = api.ReportSearchParams{Limit: limitExpected, Cursor: []any{"00:00:00:00:00:00", "0"}}
		execReq(t, http.MethodPost, "/api/v1.2/dynamic_report/Node::Report::Test::CursorMultiType/search", &payload, http.StatusOK, &body)
		isEqInt(t, "Items", len(body.Items), limitExpected)
		isEqArr(t, "PrevCursor", body.PrevCursor.([]any), []any{"00:00:00:00:00:2e", 1.0})
		isEqArr(t, "NextCursor", body.NextCursor.([]any), []any{"00:00:00:00:00:3e", 1.0})
	})
	t.Run("Check cursor field unallowed binding", func(t *testing.T) {
		var body reportSearchResponse
		limitExpected := 4
		payload := api.ReportSearchParams{Limit: limitExpected, Cursor: "00:00:00:00:00:00"}
		execReq(t, http.MethodPost, "/api/v1.2/dynamic_report/Node::Report::Test::BindingIsAColumn/search", &payload, http.StatusBadRequest, &body)
	})
}

func TestMain(m *testing.M) {
	var err error
	router, err = initRouterAndDb()
	if err != nil {
		fmt.Printf("Cannot initialize router and db: %s", err.Error())
		os.Exit(1)
	}
	err = test_helpers.RunStatements(setupSql[:])
	if err != nil {
		fmt.Printf("Cannot setup test data: %s", err.Error())
		os.Exit(1)
	}
	code := m.Run()
	err = test_helpers.RunStatements(cleanupSql[:])
	if err != nil {
		fmt.Printf("Cannot cleanup test data: %s", err.Error())
		os.Exit(1)
	}
	os.Exit(code)
}

func isEqStr(t *testing.T, extra_log string, actual, expected string) {
	if expected != actual {
		if len(extra_log) == 0 {
			t.Fatalf("Expected '%s', got '%s'", expected, actual)
		} else {
			t.Fatalf("[%s] Expected '%s', got '%s'", extra_log, expected, actual)
		}
	}
}

func isEqInt(t *testing.T, extra_log string, actual, expected int) {
	if expected != actual {
		if len(extra_log) == 0 {
			t.Fatalf("Expected %d, got %d", expected, actual)
		} else {
			t.Fatalf("[%s] Expected %d, got %d", extra_log, expected, actual)
		}
	}
}

func isEqBool(t *testing.T, extra_log string, actual, expected bool) {
	if expected != actual {
		if len(extra_log) == 0 {
			t.Fatalf("Expected %t, got %t", expected, actual)
		} else {
			t.Fatalf("[%s] Expected %t, got %t", extra_log, expected, actual)
		}
	}
}

func isGT(t *testing.T, extra_log string, actual, expected int) {
	if actual <= expected {
		if len(extra_log) == 0 {
			t.Fatalf("Expected >%d, got %d", expected, actual)
		} else {
			t.Fatalf("[%s] Expected >%d, got %d", extra_log, expected, actual)
		}
	}
}

func isGTE(t *testing.T, extra_log string, actual, expected int) {
	if actual < expected {
		if len(extra_log) == 0 {
			t.Fatalf("Expected >=%d, got %d", expected, actual)
		} else {
			t.Fatalf("[%s] Expected >=%d, got %d", extra_log, expected, actual)
		}
	}
}

func isLT(t *testing.T, extra_log string, actual, expected int) {
	if actual >= expected {
		if len(extra_log) == 0 {
			t.Fatalf("Expected <%d, got %d", expected, actual)
		} else {
			t.Fatalf("[%s] Expected <%d, got %d", extra_log, expected, actual)
		}
	}
}

func isLTE(t *testing.T, extra_log string, actual, expected int) {
	if actual > expected {
		if len(extra_log) == 0 {
			t.Fatalf("Expected <=%d, got %d", expected, actual)
		} else {
			t.Fatalf("[%s] Expected <=%d, got %d", extra_log, expected, actual)
		}
	}
}

func isEqArr(t *testing.T, extra_log string, actual, expected []any) {
	if !slices.Equal(actual, expected) {
		if len(extra_log) == 0 {
			t.Fatalf("Array not equal: %v => %v", expected, actual)
		} else {
			t.Fatalf("[%s] Array not equal: %v => %v", extra_log, expected, actual)
		}
	}
}

func isNil(t *testing.T, extra_log string, actual any) {
	if actual != nil {
		if len(extra_log) == 0 {
			t.Fatalf("Expected nil value")
		} else {
			t.Fatalf("[%s] Expected nil value", extra_log)
		}
	}
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
		var errBody wip.ApiSerializer
		err = json.Unmarshal(body, &errBody)
		if err != nil {
			t.Fatalf("Cannot unmarshall: %s", err.Error())
		}
		t.Fatalf("Expected status %d, got %d: %v", statusExpected, res.StatusCode, errBody.Errors)
	}
	err = json.Unmarshal(body, bodyOut)
	if err != nil {
		t.Fatalf("Cannot unmarshall: %s", err.Error())
	}
}

func initRouterAndDb() (*httprouter.Router, error) {
	ctx := context.Background()
	DB, err := gorm.Open(mysql.Open(db.ReturnURIFromConfig(ctx)), &gorm.Config{})
	if err != nil {
		return nil, fmt.Errorf("Cannot open db %s", err.Error())
	}
	tmpRouter := httprouter.New()
	reportHandler := api.NewDynamicReport(context.Background(), &DB)
	reportHandler.AddToRouter(tmpRouter)
	return tmpRouter, nil
}
