package models

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"gorm.io/gorm"
)

type AuthLog struct {
	ID          int64      `json:"id,omitempty" gorm:"primary_key"`
	ProcessName string     `json:"process_name,omitempty"`
	Mac         string     `json:"mac,omitempty"`
	Pid         string     `json:"pid,omitempty" gorm:"default:'default'"`
	Status      string     `json:"status,omitempty" gorm:"default:'incomplete'"`
	AttemptedAt *time.Time `json:"attempted_at"`
	CompletedAt *time.Time `json:"completed_at"`
	Source      string     `json:"source,omitempty"`
	Profile     string     `json:"profile,omitempty"`

	DB  *gorm.DB         `json:"-" gorm:"-"`
	Ctx *context.Context `json:"-" gorm:"-"`
}

func (a AuthLog) TableName() string {
	return "auth_log"
}

// AuthLog
func NewAuthLogModel(dbp **gorm.DB, ctx *context.Context) *AuthLog {
	ret := &AuthLog{}
	ret.DB = *dbp
	ret.Ctx = ctx
	return ret
}

func (a AuthLog) Paginated(vars sql.Vars) (DBRes, error) {
	var res = DBRes{}
	var count int64

	a.DB.Model(&AuthLog{}).Count(&count)
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
		var items []AuthLog
		db := a.DB.Select(sqls.Select).Order(sqls.Order).Offset(sqls.Offset).Limit(sqls.Limit).Find(&items)
		if db.Error != nil {
			return DBRes{}, db.Error
		}
		res.Items = items
	}
	return res, nil
}

func (a AuthLog) Search(vars sql.Vars) (DBRes, error) {
	res := DBRes{}
	sqls, err := vars.Sql(a)
	if err != nil {
		return res, err
	}

	var count int64
	var items []AuthLog
	a.DB.Model(&AuthLog{}).Where(sqls.Where.Query, sqls.Where.Values...).Count(&count)

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

func (a AuthLog) GetByID(id string) (DBRes, error) {
	res := DBRes{}
	var item AuthLog

	allFields := strings.Join(sql.SqlFields(a)[:], ",")
	db := a.DB.Select(allFields).Where("`id` = ?", id).First(&item)
	if db.Error == nil {
		res.Item = item
	}
	return res, db.Error
}

func (a AuthLog) Delete(id string) (DBRes, error) {
	res := DBRes{}
	var item AuthLog
	db := a.DB.Where("`id` = ?", id).Find(&item)
	if db.Error != nil {
		return res, db.Error
	}
	err := a.DB.Unscoped().Delete(item).Error
	return res, err
}

func (a AuthLog) Update() (DBRes, error) {
	var item AuthLog
	res := DBRes{}

	err := a.DB.Model(&AuthLog{}).Where("id = ?", a.ID).Updates(a).Error

	if err != nil {
		return DBRes{}, err
	}
	allFields := strings.Join(sql.SqlFields(a)[:], ",")
	a.DB.Select(allFields).Where("`id` = ?", a.ID).First(&item)

	res.Item = item
	return res, nil
}
