package api

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/inverse-inc/packetfence/go/admin_api_audit_log"
	"github.com/inverse-inc/packetfence/go/dal/models"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/julienschmidt/httprouter"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

func GetGormDB(t *testing.T) *gorm.DB {
	database, err := gorm.Open(mysql.Open(db.ReturnURIFromConfig(context.Background())), &gorm.Config{})
	if err != nil {
		t.Fatalf("Cannot create a database connection: %s", err.Error())
		return nil
	}

	return database
}

var dbEntryIDs []int64

func setupTestCase(t *testing.T) func(t *testing.T) {
	//t.Log("setup test case")
	dbEntryIDs = []int64{}
	err, entry1 := insertDBTestEntries(t)
	if err != nil {
		t.Fatalf("error in preparing testing data\n")
	}
	err, entry2 := insertDBTestEntries(t)
	if err != nil {
		t.Fatalf("error in preparing testing data\n")
	}

	dbEntryIDs = append(dbEntryIDs, entry1.ID, entry2.ID)

	return func(t *testing.T) {
		//t.Log("teardown test case")
		for _, id := range dbEntryIDs {
			err := removeDBTestEntries(t, id)
			if err != nil {
				t.Fatalf("error in removing test entires\n")
			}
		}
	}
}

func insertDBTestEntries(t *testing.T) (error, admin_api_audit_log.AdminApiAuditLog) {
	db := GetGormDB(t)

	log := admin_api_audit_log.AdminApiAuditLog{
		UserName: "go_unit_test_user_dummy",
		Url:      "https://example.com/test",
		Request:  `{"dummy": "dummy"}`,
		Method:   "POST",
		Status:   200,
	}
	err := admin_api_audit_log.Add(db, &log)
	return err, log
}

func removeDBTestEntries(t *testing.T, id int64) error {
	db := GetGormDB(t)
	l := admin_api_audit_log.AdminApiAuditLog{ID: id}
	err := admin_api_audit_log.Remove(db, &l)

	return err
}

func dalAdminApiAuditLog() http.HandlerFunc {
	router := httprouter.New()
	ctx := context.Background()
	dbs, err := gorm.Open(mysql.Open(db.ReturnURIFromConfig(ctx)), &gorm.Config{})
	if err != nil {
		fmt.Println("error occured while connecting to mysql, ", err.Error())
	}
	NewAdminApiAuditLog(ctx, &dbs).AddToRouter(router)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if handle, params, _ := router.Lookup(r.Method, r.URL.Path); handle != nil {
			// We always default to application/json
			w.Header().Set("Content-Type", "application/json")
			handle(w, r, params)
			return
		}
		w.WriteHeader(500)
		io.WriteString(w, "{}")
	})
}

func TestList(t *testing.T) {
	teardownTestCase := setupTestCase(t)
	defer teardownTestCase(t)

	handler := dalAdminApiAuditLog()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/admin_api_audit_logs", nil)
	w := httptest.NewRecorder()
	handler(w, req)
	res := w.Result()
	defer res.Body.Close()
	data, err := ioutil.ReadAll(res.Body)
	if err != nil {
		t.Fatalf("Error: %s", err.Error())
	} else {
		if res.StatusCode != http.StatusOK {
			t.Fatalf("Error: unexpected http response code")
		}

		respBody := RespBody{}
		err := json.Unmarshal(data, &respBody)
		if err != nil {
			t.Fatalf("Error: %s: ", err.Error())
		}

		itemsJson, err := json.Marshal(respBody.Items)
		if err != nil {
			t.Fatalf("Error: %s: ", err.Error())
		}
		items := []models.AdminApiAuditLog{}
		err = json.Unmarshal(itemsJson, &items)
		if err != nil {
			t.Fatalf("unable to decode response database entries")
		}
		if len(items) < 2 {
			t.Fatalf("unable to retrieve expected data entries")
		}
	}
}

func TestSearch(t *testing.T) {
	teardownTestCase := setupTestCase(t)
	defer teardownTestCase(t)

	if len(dbEntryIDs) < 2 {
		t.Fatalf("error in generating test db entries\n")
	}

	type ValueS struct {
		Op    string `json:"op"`
		Value int64  `json:"value"`
		Field string `json:"field"`
	}
	type QueryS struct {
		Op     string   `json:"op"`
		Values []ValueS `json:"values"`
	}
	type PayloadS struct {
		Query QueryS `json:"query"`
	}

	var values []ValueS
	for _, v := range dbEntryIDs {
		values = append(values, ValueS{Op: "equals", Value: v, Field: "id"})
	}

	payload := PayloadS{
		Query: QueryS{
			Op:     "or",
			Values: values,
		},
	}

	searchPayloadJson, _ := json.Marshal(payload)

	handler := dalAdminApiAuditLog()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/admin_api_audit_logs/search", bytes.NewBuffer(searchPayloadJson))
	w := httptest.NewRecorder()
	handler(w, req)
	res := w.Result()
	defer res.Body.Close()
	data, err := ioutil.ReadAll(res.Body)
	if err != nil {
		t.Fatalf("Error: %s", err.Error())
	} else {
		if res.StatusCode != http.StatusOK {
			t.Fatalf("Error: unexpected http response code")
		}

		respBody := RespBody{}
		err := json.Unmarshal(data, &respBody)
		if err != nil {
			t.Fatalf("Error: %s: ", err.Error())
		}

		itemsJson, err := json.Marshal(respBody.Items)
		if err != nil {
			t.Fatalf("Error: %s: ", err.Error())
		}

		items := []models.AdminApiAuditLog{}
		err = json.Unmarshal(itemsJson, &items)
		if err != nil {
			t.Fatalf("unable to decode response database entries")
		}
		if len(items) < 2 {
			t.Fatalf("unable to retrieve expected data entries")
		}

		mapEntryIDs := make(map[int64]bool)
		for _, entryID := range dbEntryIDs {
			mapEntryIDs[entryID] = true
		}
		for _, item := range items {
			_, ok := mapEntryIDs[item.ID]
			if ok == false {
				t.Fatalf("unable to retrieve expected entries\n")
			}
		}
	}

}

func TestGet(t *testing.T) {
	teardownTestCase := setupTestCase(t)
	defer teardownTestCase(t)

	if len(dbEntryIDs) < 2 {
		t.Fatalf("error in generating test db entries\n")
	}

	expectedEntryID := dbEntryIDs[0]

	handler := dalAdminApiAuditLog()
	URL := fmt.Sprintf("/api/v1/admin_api_audit_log/%d", expectedEntryID)
	req := httptest.NewRequest(http.MethodGet, URL, nil)

	w := httptest.NewRecorder()
	handler(w, req)
	res := w.Result()
	defer res.Body.Close()
	data, err := ioutil.ReadAll(res.Body)

	if err != nil {
		t.Fatalf("Error: %s", err.Error())
	} else {
		if res.StatusCode != http.StatusOK {
			t.Fatalf("Error: unexpected http response code")
		}

		respBody := RespBody{}
		err := json.Unmarshal(data, &respBody)
		if err != nil {
			t.Fatalf("Error: %s: ", err.Error())
		}

		itemJson, err := json.Marshal(respBody.Item)
		if err != nil {
			t.Fatalf("Error: %s: ", err.Error())
		}

		item := models.AdminApiAuditLog{}
		err = json.Unmarshal(itemJson, &item)
		if err != nil {
			t.Fatalf("unable to decode response database entries")
		}

		if item.ID != expectedEntryID {
			t.Fatalf("unable to retrieve expected entries")
		}
	}
}
