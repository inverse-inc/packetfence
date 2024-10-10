package models

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"

	"gorm.io/gorm"
)

type RadacctLog struct {
	ID               int64      `json:"id,omitempty" gorm:"primary_key"`
	AcctSessionID    string     `json:"acctsessionid,omitempty" gorm:"column:acctsessionid;default:''"`
	UserName         string     `json:"username,omitempty" gorm:"column:username;default:''"`
	NasIPAddress     string     `json:"nasipaddress,omitempty" gorm:"column:nasipaddress;default:''"`
	AcctStatusType   string     `json:"acctstatustype,omitempty" gorm:"column:acctstatustype;default:''"`
	Timestamp        *time.Time `json:"timestamp,omitempty"`
	AcctInputOctets  int64      `json:"acctinputoctets,omitempty" gorm:"column:acctinputoctets"`
	AcctOutputOctets int64      `json:"acctoutputoctets,omitempty" gorm:"column:acctoutputoctets"`
	AcctSessionTime  int        `json:"acctsessiontime,omitempty" gorm:"column:acctsessiontime"`
	AcctUniqueID     string     `json:"acctuniqueid,omitempty" gorm:"column:acctuniqueid;default:''"`

	DB  *gorm.DB         `json:"-" gorm:"-"`
	Ctx *context.Context `json:"-" gorm:"-"`
}

func (r RadacctLog) TableName() string {
	return "radacct_log"
}

// RadacctLog
func NewRadacctLogModel(dbp **gorm.DB, ctx *context.Context) *RadacctLog {
	ret := &RadacctLog{}
	ret.DB = *dbp
	ret.Ctx = ctx
	return ret
}
func (a RadacctLog) Paginated(vars sql.Vars) (DBRes, error) {
	var res = DBRes{}
	var count int64

	a.DB.Model(&RadacctLog{}).Count(&count)
	counter := int(count)
	res.Total = &counter
	res.PrevCursor = &vars.Cursor
	nextCursor := vars.Cursor + vars.Limit
	res.NextCursor = &nextCursor

	if vars.Cursor < counter {
		sqls, err := vars.Sql(a)
		if err != nil {
			return DBRes{}, err
		}
		var items []RadacctLog
		db := a.DB.Select(sqls.Select).Order(sqls.Order).Offset(sqls.Offset).Limit(sqls.Limit).Find(&items)
		if db.Error != nil {
			return DBRes{}, db.Error
		}
		res.Items = items
	}
	return res, nil
}

func (a RadacctLog) Search(vars sql.Vars) (DBRes, error) {
	res := DBRes{}
	sqls, err := vars.Sql(a)
	if err != nil {
		return res, err
	}

	var count int64
	var items []RadacctLog
	a.DB.Model(&RadacctLog{}).Where(sqls.Where.Query, sqls.Where.Values...).Count(&count)

	if count == 0 {
		return res, errors.New("entries not found")
	}

	counter := int(count)
	res.Total = &counter
	res.PrevCursor = &vars.Cursor
	nextCursor := vars.Cursor + vars.Limit
	res.NextCursor = &nextCursor

	if vars.Cursor < counter {
		db := a.DB.Select(sqls.Select).Where(sqls.Where.Query, sqls.Where.Values...).Order(sqls.Order).Offset(sqls.Offset).Limit(sqls.Limit).Find(&items)
		if db.Error != nil {
			return DBRes{}, db.Error
		}
		res.Items = items
	}
	return res, nil
}

func (a RadacctLog) GetByID(id string) (DBRes, error) {
	res := DBRes{}
	var item RadacctLog

	allFields := strings.Join(sql.SqlFields(a)[:], ",")
	db := a.DB.Select(allFields).Where("`id` = ?", id).First(&item)
	if db.Error == nil {
		res.Item = item
	}
	return res, db.Error
}

func (a RadacctLog) Delete(id string) (DBRes, error) {
	res := DBRes{}
	var item RadacctLog
	db := a.DB.Where("`id` = ?", id).Find(&item)
	if db.Error != nil {
		return res, db.Error
	}
	err := a.DB.Unscoped().Delete(item).Error
	return res, err
}

func (a RadacctLog) Update() (DBRes, error) {
	var item RadacctLog
	res := DBRes{}

	err := a.DB.Model(&RadacctLog{}).Where("id = ?", a.ID).Updates(a).Error

	if err != nil {
		return DBRes{}, err
	}
	allFields := strings.Join(sql.SqlFields(a)[:], ",")
	a.DB.Select(allFields).Where("`id` = ?", a.ID).First(&item)

	res.Item = item
	return res, nil
}
