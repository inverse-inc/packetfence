package api

import (
	"context"
	"fmt"
	"github.com/inverse-inc/packetfence/go/admin_api_audit_log"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/jinzhu/gorm"
	"io"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/julienschmidt/httprouter"
)

func getGormDB(t *testing.T) *gorm.DB {
	database, err := gorm.Open("mysql", db.ReturnURIFromConfig(context.Background()))
	if err != nil {
		t.Fatalf("Cannot create a database connection: %s", err.Error())
		return nil
	}

	return database
}

func dalAdminApiAuditLog() http.HandlerFunc {
	router := httprouter.New()
	NewAdminApiAuditLog().AddToRouter(router)
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

	db := getGormDB(t)

	log := admin_api_audit_log.AdminApiAuditLog{
		Method: "POST",
		Status: 200,
	}
	err := admin_api_audit_log.Add(db, &log)
	fmt.Println(err)

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
		//Add additional checks
		fmt.Printf("Data: %s\n", string(data))
	}
}

func TestMain(m *testing.M) {
	fmt.Println("test of admin_api_audit_logs beings...")
	m.Run()
	fmt.Println("test of admin_api_audit_logs ends...")
}
