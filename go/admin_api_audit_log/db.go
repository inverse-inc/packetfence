package admin_api_audit_log

import (
	"github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/mysql"
	"time"
)

type AdminApiAuditLog struct {
	ID        int64
	CreatedAt time.Time
	UserName  string
	Url       string
	Action    string
	ObjectId  string
	Method    string
	Request   string
	Status    int16
}

func (*AdminApiAuditLog) TableName() string {
	return "admin_api_audit_log"
}

func Add(db *gorm.DB, log *AdminApiAuditLog) error {
	results := db.Create(log)
	return results.Error
}

func (l *AdminApiAuditLog) Add(db *gorm.DB) error {
	return Add(db, l)
}
