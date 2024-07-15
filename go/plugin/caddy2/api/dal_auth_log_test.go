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
	"time"

	"github.com/inverse-inc/packetfence/go/dal/models"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/julienschmidt/httprouter"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

var authLogIDs []int64

func setupTestCaseAuthLog(t *testing.T) func(t *testing.T) {
	//t.Log("setup test case")
	authLogIDs = []int64{}
	err, entry1 := insertDBTestEntriesAuthLog(t)
	if err != nil {
		t.Fatalf("error in preparing testing data\n")
	}
	err, entry2 := insertDBTestEntriesAuthLog(t)
	if err != nil {
		t.Fatalf("error in preparing testing data\n")
	}

	authLogIDs = append(authLogIDs, entry1.ID, entry2.ID)

	return func(t *testing.T) {
		//t.Log("teardown test case")
		for _, id := range authLogIDs {
			err := removeDBTestEntriesAuthLog(t, id)
			if err != nil {
				t.Fatalf("error in removing test entires\n")
			}
		}
	}
}

func insertDBTestEntriesAuthLog(t *testing.T) (error, models.AuthLog) {
	db := GetGormDB(t)

	now := time.Now()
	entry := models.AuthLog{
		ProcessName: "test",
		Mac:         "00:00:00:11:11:11",
		Status:      "complete",
		AttemptedAt: &now,
	}
	results := db.Model(&models.AuthLog{}).Create(&entry)
	err := results.Error

	return err, entry
}

func removeDBTestEntriesAuthLog(t *testing.T, id int64) error {
	db := GetGormDB(t)
	l := models.AuthLog{ID: id}
	err := db.Where("`id` = ?", l.ID).Unscoped().Delete(l).Error

	return err
}

func dalAuthLog() http.HandlerFunc {
	router := httprouter.New()
	ctx := context.Background()
	dbs, err := gorm.Open(mysql.Open(db.ReturnURIFromConfig(ctx)), &gorm.Config{})
	if err != nil {
		fmt.Println("error occured while connecting to mysql, ", err.Error())
	}
	NewAuthLog(ctx, &dbs).AddToRouter(router)
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

func TestListAuthLog(t *testing.T) {
	teardownTestCase := setupTestCaseAuthLog(t)
	defer teardownTestCase(t)

	handler := dalAuthLog()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/auth_logs", nil)
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
		items := []models.AuthLog{}
		err = json.Unmarshal(itemsJson, &items)
		if err != nil {
			t.Fatalf("unable to decode response database entries")
		}
		if len(items) < 2 {
			t.Fatalf("unable to retrieve expected data entries")
		}
	}
}

func TestSearchAuthLog(t *testing.T) {
	teardownTestCase := setupTestCaseAuthLog(t)
	defer teardownTestCase(t)

	if len(authLogIDs) < 2 {
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
	for _, v := range authLogIDs {
		values = append(values, ValueS{Op: "equals", Value: v, Field: "id"})
	}

	payload := PayloadS{
		Query: QueryS{
			Op:     "or",
			Values: values,
		},
	}

	searchPayloadJson, _ := json.Marshal(payload)

	handler := dalAuthLog()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth_logs/search", bytes.NewBuffer(searchPayloadJson))
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

		items := []models.AuthLog{}
		err = json.Unmarshal(itemsJson, &items)
		if err != nil {
			t.Fatalf("unable to decode response database entries")
		}
		if len(items) < 2 {
			t.Fatalf("unable to retrieve expected data entries")
		}

		mapEntryIDs := make(map[int64]bool)
		for _, entryID := range authLogIDs {
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

func TestGetAuthLog(t *testing.T) {
	teardownTestCase := setupTestCaseAuthLog(t)
	defer teardownTestCase(t)

	if len(authLogIDs) < 2 {
		t.Fatalf("error in generating test db entries\n")
	}

	expectedEntryID := authLogIDs[0]

	handler := dalAuthLog()
	URL := fmt.Sprintf("/api/v1/auth_log/%d", expectedEntryID)
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

		item := models.AuthLog{}
		err = json.Unmarshal(itemJson, &item)
		if err != nil {
			t.Fatalf("unable to decode response database entries")
		}

		if item.ID != expectedEntryID {
			t.Fatalf("unable to retrieve expected entries")
		}
	}
}
