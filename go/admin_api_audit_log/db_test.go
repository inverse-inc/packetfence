package admin_api_audit_log

import (
	"context"
	"testing"

	"github.com/inverse-inc/packetfence/go/db"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

func TestLogAdd(t *testing.T) {
	db := getGormDB(t)
	log := AdminApiAuditLog{
		Method: "POST",
		Status: 200,
	}
	err := Add(db, &log)
	if err != nil {
		t.Fatalf("Cannot create a admin_api_audit_log: %s", err.Error())
	}

}

func getGormDB(t *testing.T) *gorm.DB {
	database, err := gorm.Open(mysql.Open(db.ReturnURIFromConfig(context.Background())), &gorm.Config{})
	if err != nil {
		t.Fatalf("Cannot create a database connection: %s", err.Error())
		return nil
	}

	return database
}
