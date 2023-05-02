package models

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/jinzhu/gorm"
)

type AdminApiAuditLog struct {
	ID        int64      `json:"id,omitempty" gorm:"primary_key"`
	CreatedAt *time.Time `json:"created_at,omitempty"`
	UserName  string     `json:"user_name,omitempty"`
	Url       string     `json:"url,omitempty"`
	Action    string     `json:"action,omitempty"`
	ObjectId  string     `json:"object_id,omitempty"`
	Method    string     `json:"method,omitempty"`
	Request   string     `json:"request,omitempty"`
	Status    int16      `json:"status,omitempty"`

	DB  *gorm.DB         `json:"-" gorm:"-"`
	Ctx *context.Context `json:"-" gorm:"-"`
}

func (a AdminApiAuditLog) TableName() string {
	return "admin_api_audit_log"
}

func NewAdminApiAuditLogModel(db *gorm.DB, ctx *context.Context) *AdminApiAuditLog {
	ret := &AdminApiAuditLog{}
	ret.DB = db
	ret.Ctx = ctx
	return ret
}

func (a AdminApiAuditLog) Paginated(vars sql.Vars) (DBRes, error) {
	var res = DBRes{}
	var count int

	a.DB.Model(&AdminApiAuditLog{}).Count(&count)
	res.Total = &count
	res.PrevCursor = &vars.Cursor
	nextCursor := vars.Cursor + vars.Limit
	res.NextCursor = &nextCursor

	if vars.Cursor < count {
		sqls, err := vars.Sql(a)
		if err != nil {
			return DBRes{}, err
		}
		var items []AdminApiAuditLog
		db := a.DB.Select(sqls.Select).Order(sqls.Order).Offset(sqls.Offset).Limit(sqls.Limit).Find(&items)
		if db.Error != nil {
			return DBRes{}, db.Error
		}
		res.Items = items
	}
	return res, nil
}

func (a AdminApiAuditLog) Search(vars sql.Vars) (DBRes, error) {
	res := DBRes{}
	sqls, err := vars.Sql(a)
	if err != nil {
		return res, err
	}

	var count int
	var items []AdminApiAuditLog
	a.DB.Model(&AdminApiAuditLog{}).Where(sqls.Where.Query, sqls.Where.Values...).Count(&count)

	if count == 0 {
		return res, errors.New("entries not found")
	}

	res.Total = &count
	res.PrevCursor = &vars.Cursor
	nextCursor := vars.Cursor + vars.Limit
	res.NextCursor = &nextCursor

	if vars.Cursor < count {
		db := a.DB.Select(sqls.Select).Where(sqls.Where.Query, sqls.Where.Values...).Order(sqls.Order).Offset(sqls.Offset).Limit(sqls.Limit).Find(&items)
		if db.Error != nil {
			return DBRes{}, db.Error
		}
		res.Items = items
	}
	return res, nil
}

func (a AdminApiAuditLog) GetByID(id string) (DBRes, error) {
	res := DBRes{}
	var item AdminApiAuditLog

	allFields := strings.Join(sql.SqlFields(a)[:], ",")
	db := a.DB.Select(allFields).Where("`id` = ?", id).First(&item)
	if db.Error == nil {
		res.Item = item
	}
	return res, db.Error
}

func (a AdminApiAuditLog) Delete(id string) (DBRes, error) {
	res := DBRes{}
	var item AdminApiAuditLog
	db := a.DB.Where("`id` = ?", id).Find(&item)
	if db.Error != nil {
		return res, db.Error
	}
	err := a.DB.Unscoped().Delete(item).Error
	return res, err
}

func (a AdminApiAuditLog) Update() (DBRes, error) {
	var item AdminApiAuditLog
	res := DBRes{}

	err := a.DB.Model(&AdminApiAuditLog{}).Where("id = ?", a.ID).Updates(a).Error

	if err != nil {
		return DBRes{}, err
	}
	allFields := strings.Join(sql.SqlFields(a)[:], ",")
	a.DB.Select(allFields).Where("`id` = ?", a.ID).First(&item)

	res.Item = item
	return res, nil
}
