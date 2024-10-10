package admin_api_audit_log

import (
	"time"

	_ "gorm.io/driver/mysql"
	"gorm.io/gorm"
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

func Remove(db *gorm.DB, l *AdminApiAuditLog) error {
	err := db.Where("`id` = ? ", l.ID).Unscoped().Delete(l)
	return err.Error
}

func (l *AdminApiAuditLog) Add(db *gorm.DB) error {
	return Add(db, l)
}
