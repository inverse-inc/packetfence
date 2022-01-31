package admin_api_audit_log

import (
	"context"
	"github.com/inverse-inc/packetfence/go/db"
	"github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/mysql"
	"testing"
)

func TestLogAdd(t *testing.T) {
	db := getGormDB(t)
	log := AdminApiAuditLog{
		TenantId: 1,
		Method:   "POST",
		Status:   200,
	}
	err := Add(db, &log)
	if err != nil {
		t.Fatalf("Cannot create a admin_api_audit_log: %s", err.Error())
	}

}

func getGormDB(t *testing.T) *gorm.DB {
	database, err := gorm.Open("mysql", db.ReturnURIFromConfig(context.Background()))
	if err != nil {
		t.Fatalf("Cannot create a database connection: %s", err.Error())
		return nil
	}

	return database
}
