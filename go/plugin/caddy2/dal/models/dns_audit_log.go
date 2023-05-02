package models

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/jinzhu/gorm"
)

type DnsAuditLog struct {
	ID        int64      `json:"id,omitempty" gorm:"primary_key"`
	CreatedAt *time.Time `json:"created_at,omitempty"`
	IP        string     `json:"ip,omitempty"`
	Mac       string     `json:"mac,omitempty"`
	QName     string     `json:"qname,omitempty" gorm:"column:qname"`
	QType     string     `json:"qtype,omitempty" gorm:"column:qtype"`
	Scope     string     `json:"scope,omitempty"`
	Answer    string     `json:"answer,omitempty"`

	DB  *gorm.DB         `json:"-" gorm:"-"`
	Ctx *context.Context `json:"-" gorm:"-"`
}

func (d DnsAuditLog) TableName() string {
	return "dns_audit_log"
}

// DnsAuditLog
func NewDnsAuditLogModel(db *gorm.DB, ctx *context.Context) *DnsAuditLog {
	ret := &DnsAuditLog{}
	ret.DB = db
	ret.Ctx = ctx
	return ret
}
func (a DnsAuditLog) Paginated(vars sql.Vars) (DBRes, error) {
	var res = DBRes{}
	var count int

	a.DB.Model(&DnsAuditLog{}).Count(&count)
	res.Total = &count
	res.PrevCursor = &vars.Cursor
	nextCursor := vars.Cursor + vars.Limit
	res.NextCursor = &nextCursor

	if vars.Cursor < count {
		sqls, err := vars.Sql(a)
		if err != nil {
			return DBRes{}, err
		}
		var items []DnsAuditLog
		db := a.DB.Select(sqls.Select).Order(sqls.Order).Offset(sqls.Offset).Limit(sqls.Limit).Find(&items)
		if db.Error != nil {
			return DBRes{}, db.Error
		}
		res.Items = items
	}
	return res, nil
}

func (a DnsAuditLog) Search(vars sql.Vars) (DBRes, error) {
	res := DBRes{}
	sqls, err := vars.Sql(a)
	if err != nil {
		return res, err
	}

	var count int
	var items []DnsAuditLog
	a.DB.Model(&DnsAuditLog{}).Where(sqls.Where.Query, sqls.Where.Values...).Count(&count)

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

func (a DnsAuditLog) GetByID(id string) (DBRes, error) {
	res := DBRes{}
	var item DnsAuditLog

	allFields := strings.Join(sql.SqlFields(a)[:], ",")
	db := a.DB.Select(allFields).Where("`id` = ?", id).First(&item)
	if db.Error == nil {
		res.Item = item
	}
	return res, db.Error
}

func (a DnsAuditLog) Delete(id string) (DBRes, error) {
	res := DBRes{}
	var item DnsAuditLog
	db := a.DB.Where("`id` = ?", id).Find(&item)
	if db.Error != nil {
		return res, db.Error
	}
	err := a.DB.Unscoped().Delete(item).Error
	return res, err
}

func (a DnsAuditLog) Update() (DBRes, error) {
	var item DnsAuditLog
	res := DBRes{}

	err := a.DB.Model(&DnsAuditLog{}).Where("id = ?", a.ID).Updates(a).Error

	if err != nil {
		return DBRes{}, err
	}
	allFields := strings.Join(sql.SqlFields(a)[:], ",")
	a.DB.Select(allFields).Where("`id` = ?", a.ID).First(&item)

	res.Item = item
	return res, nil
}
