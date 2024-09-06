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

	"github.com/google/uuid"
	"github.com/inverse-inc/packetfence/go/dal/models"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/julienschmidt/httprouter"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

var WrixIDs []string

func setupTestCaseWrix(t *testing.T) func(t *testing.T) {
	//t.Log("setup test case")
	WrixIDs = []string{}
	err, entry1 := insertDBTestEntriesWrix(t)
	if err != nil {
		t.Fatalf("error in preparing testing data\n")
	}
	err, entry2 := insertDBTestEntriesWrix(t)
	if err != nil {
		t.Fatalf("error in preparing testing data\n")
	}

	WrixIDs = append(WrixIDs, entry1.ID, entry2.ID)

	return func(t *testing.T) {
		//t.Log("teardown test case")
		for _, id := range WrixIDs {
			err := removeDBTestEntriesWrix(t, id)
			if err != nil {
				t.Fatalf("error in removing test entires\n")
			}
		}
	}
}

func insertDBTestEntriesWrix(t *testing.T) (error, models.Wrix) {
	db := GetGormDB(t)

	id, _ := uuid.NewUUID()
	entry := models.Wrix{
		ID:                 id.String(),
		ProviderIdentifier: "Cisco",
		SSIDBroadcasted:    "Yes",
		MACAddress:         "01:02:03:04:05:06",
	}
	results := db.Model(&models.Wrix{}).Create(&entry)
	err := results.Error

	return err, entry
}

func removeDBTestEntriesWrix(t *testing.T, id string) error {
	db := GetGormDB(t)
	l := models.Wrix{ID: id}
	err := db.Where("`id` = ?", l.ID).Unscoped().Delete(l).Error

	return err
}

func dalWrix() http.HandlerFunc {
	router := httprouter.New()
	ctx := context.Background()
	dbs, err := gorm.Open(mysql.Open(db.ReturnURIFromConfig(ctx)), &gorm.Config{})
	if err != nil {
		fmt.Println("error occured while connecting to mysql, ", err.Error())
	}

	NewWrix(ctx, &dbs).AddToRouter(router)
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

func TestListWrixes(t *testing.T) {
	teardownTestCase := setupTestCaseWrix(t)
	defer teardownTestCase(t)

	handler := dalWrix()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/wrixes", nil)
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
		items := []models.Wrix{}
		err = json.Unmarshal(itemsJson, &items)
		if err != nil {
			t.Fatalf("unable to decode response database entries")
		}
		if len(items) < 2 {
			t.Fatalf("unable to retrieve expected data entries")
		}
	}
}

func TestSearchWrix(t *testing.T) {
	teardownTestCase := setupTestCaseWrix(t)
	defer teardownTestCase(t)

	if len(WrixIDs) < 2 {
		t.Fatalf("error in generating test db entries\n")
	}

	type ValueS struct {
		Op    string `json:"op"`
		Value string `json:"value"`
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
	for _, v := range WrixIDs {
		values = append(values, ValueS{Op: "equals", Value: v, Field: "id"})
	}

	payload := PayloadS{
		Query: QueryS{
			Op:     "or",
			Values: values,
		},
	}

	searchPayloadJson, _ := json.Marshal(payload)

	handler := dalWrix()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/wrixes/search", bytes.NewBuffer(searchPayloadJson))
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

		items := []models.Wrix{}
		err = json.Unmarshal(itemsJson, &items)
		if err != nil {
			t.Fatalf("unable to decode response database entries")
		}
		if len(items) < 2 {
			t.Fatalf("unable to retrieve expected data entries")
		}

		mapEntryIDs := make(map[string]bool)
		for _, entryID := range WrixIDs {
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

func TestGetWrix(t *testing.T) {
	teardownTestCase := setupTestCaseWrix(t)
	defer teardownTestCase(t)

	if len(WrixIDs) < 2 {
		t.Fatalf("error in generating test db entries\n")
	}

	expectedEntryID := WrixIDs[0]

	handler := dalWrix()
	URL := fmt.Sprintf("/api/v1/wrix/%s", expectedEntryID)
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

		item := models.Wrix{}
		err = json.Unmarshal(itemJson, &item)
		if err != nil {
			t.Fatalf("unable to decode response database entries")
		}

		if item.ID != expectedEntryID {
			t.Fatalf("unable to retrieve expected entries")
		}
	}
}

func TestUpdateWrix(t *testing.T) {
	teardownTestCase := setupTestCaseWrix(t)
	defer teardownTestCase(t)

	if len(WrixIDs) < 2 {
		t.Fatalf("error in generating test db entries\n")
	}

	expectedEntryID := WrixIDs[0]
	payloadJson := `{"MAC_Address": "12:34:56:78:90:12", "English_Location_City": "Montreal"}`

	handler := dalWrix()
	URL := fmt.Sprintf("/api/v1/wrix/%s", expectedEntryID)
	req := httptest.NewRequest(http.MethodPatch, URL, bytes.NewBuffer([]byte(payloadJson)))
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

		item := models.Wrix{}

		err = json.Unmarshal(itemJson, &item)
		if err != nil {
			t.Fatalf("unable to decode response database entries")
		}

		if item.ID != expectedEntryID || item.MACAddress != "12:34:56:78:90:12" || item.EnglishLocationCity != "Montreal" {
			t.Fatalf("failed in updating fields")
		}
	}
}

func TestDeleteWrix(t *testing.T) {
	teardownTestCase := setupTestCaseWrix(t)
	defer teardownTestCase(t)

	if len(WrixIDs) < 2 {
		t.Fatalf("error in generating test db entries\n")
	}

	expectedEntryID := WrixIDs[0]

	handler := dalWrix()
	URL := fmt.Sprintf("/api/v1/wrix/%s", expectedEntryID)
	req := httptest.NewRequest(http.MethodDelete, URL, nil)

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
	}
}
