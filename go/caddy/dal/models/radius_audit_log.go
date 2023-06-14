package models

import (
	"context"
	"errors"
	"net/url"
	"strings"
	"time"

	"github.com/inverse-inc/packetfence/go/caddy/pfpki/sql"
	"github.com/jinzhu/gorm"
)

type RadiusAuditLog struct {
	ID                    int64      `json:"id" gorm:"primary_key"`
	CreatedAt             *time.Time `json:"created_at"`
	Mac                   string     `json:"mac"`
	IP                    *string    `json:"ip"`
	ComputerName          *string    `json:"computer_name"`
	UserName              *string    `json:"user_name"`
	StrippedUserName      *string    `json:"stripped_user_name"`
	Realm                 *string    `json:"realm"`
	EventType             *string    `json:"event_type"`
	SwitchID              *string    `json:"switch_id"`
	SwitchMAC             *string    `json:"switch_mac"`
	SwitchIPAddress       *string    `json:"switch_ip_address"`
	RadiusSourceIPAddress *string    `json:"radius_source_ip_address"`
	CalledStationID       *string    `json:"called_station_id"`
	CallingStationID      *string    `json:"calling_station_id"`
	NASPortType           *string    `json:"nas_port_type"`
	SSID                  *string    `json:"ssid" gorm:"column:ssid"`
	NASPortID             *string    `json:"nas_port_id" gorm:"column:nas_port_id"`
	IfIndex               *string    `json:"ifindex" gorm:"column:ifindex"`
	NASPort               *string    `json:"nas_port" gorm:"column:nas_port"`
	ConnectionType        *string    `json:"connection_type"`
	NASIPAddress          *string    `json:"nas_ip_address" gorm:"column:nas_ip_address"`
	NASIdentifier         *string    `json:"nas_identifier" gorm:"column:nas_identifier"`
	AuthStatus            *string    `json:"auth_status"`
	Reason                *string    `json:"reason"`
	AuthType              *string    `json:"auth_type"`
	EAPType               *string    `json:"eap_type" gorm:"column:eap_type"`
	Role                  *string    `json:"role"`
	NodeStatus            *string    `json:"node_status"`
	Profile               *string    `json:"profile"`
	Source                *string    `json:"source"`
	AutoReg               *string    `json:"auto_reg"`
	IsPhone               *string    `json:"is_phone"`
	PFDomain              *string    `json:"pf_domain" gorm:"column:pf_domain"`
	UUID                  *string    `json:"uuid"`
	RadiusRequest         *string    `json:"radius_request"`
	RadiusReply           *string    `json:"radius_reply"`
	RequestTime           *int       `json:"request_time"`
	RadiusIP              *string    `json:"radius_ip"`

	DB  *gorm.DB         `json:"-" gorm:"-"`
	Ctx *context.Context `json:"-" gorm:"-"`
}

func urldecode(s string) string {
	s = strings.ReplaceAll(s, "=", "%")
	unescaped, err := url.QueryUnescape(s)
	if err != nil {
		return s
	}
	return unescaped
}

func (r RadiusAuditLog) TableName() string {
	return "radius_audit_log"
}

// RadiusAuditLog
func NewRadiusAuditLogModel(db *gorm.DB, ctx *context.Context) *RadiusAuditLog {
	ret := &RadiusAuditLog{}
	ret.DB = db
	ret.Ctx = ctx
	return ret
}
func (a RadiusAuditLog) Paginated(vars sql.Vars) (DBRes, error) {
	var res = DBRes{}
	var count int

	a.DB.Model(&RadiusAuditLog{}).Count(&count)
	res.Total = &count
	res.PrevCursor = &vars.Cursor
	nextCursor := vars.Cursor + vars.Limit
	res.NextCursor = &nextCursor

	if vars.Cursor < count {
		sqls, err := vars.Sql(a)
		if err != nil {
			return DBRes{}, err
		}
		var items []RadiusAuditLog
		db := a.DB.Select(sqls.Select).Order(sqls.Order).Offset(sqls.Offset).Limit(sqls.Limit).Find(&items)
		if db.Error != nil {
			return DBRes{}, db.Error
		}
		for _, item := range items {
			fixupItem(&item)
		}
		res.Items = items
	}
	return res, nil
}

func fixupItem(item *RadiusAuditLog) {
	if item.RadiusRequest != nil {
		*item.RadiusRequest = urldecode(*item.RadiusRequest)
	}

	if item.RadiusReply != nil {
		*item.RadiusReply = urldecode(*item.RadiusReply)
	}
}

func (a RadiusAuditLog) Search(vars sql.Vars) (DBRes, error) {
	res := DBRes{}
	sqls, err := vars.Sql(a)
	if err != nil {
		return res, err
	}

	var count int
	var items []RadiusAuditLog
	a.DB.Model(&RadiusAuditLog{}).Where(sqls.Where.Query, sqls.Where.Values...).Count(&count)

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
		for _, item := range items {
			fixupItem(&item)
		}
		res.Items = items
	}
	return res, nil
}

func (a RadiusAuditLog) GetByID(id string) (DBRes, error) {
	res := DBRes{}
	var item RadiusAuditLog

	allFields := strings.Join(sql.SqlFields(a)[:], ",")
	db := a.DB.Select(allFields).Where("`id` = ?", id).First(&item)
	if db.Error == nil {
		fixupItem(&item)
		res.Item = item
	}
	return res, db.Error
}

func (a RadiusAuditLog) Delete(id string) (DBRes, error) {
	res := DBRes{}
	var item RadiusAuditLog
	db := a.DB.Where("`id` = ?", id).Find(&item)
	if db.Error != nil {
		return res, db.Error
	}
	err := a.DB.Unscoped().Delete(item).Error
	return res, err
}

func (a RadiusAuditLog) Update() (DBRes, error) {
	var item RadiusAuditLog
	res := DBRes{}

	err := a.DB.Model(&RadiusAuditLog{}).Where("id = ?", a.ID).Updates(a).Error

	if err != nil {
		return DBRes{}, err
	}
	allFields := strings.Join(sql.SqlFields(a)[:], ",")
	a.DB.Select(allFields).Where("`id` = ?", a.ID).First(&item)

	res.Item = item
	return res, nil
}
