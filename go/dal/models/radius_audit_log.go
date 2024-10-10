package models

import (
	"context"
	"errors"
	"net/url"
	"strings"
	"time"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"gorm.io/gorm"
)

type RadiusAuditLog struct {
	ID                    int64      `json:"id,omitempty" gorm:"primary_key"`
	CreatedAt             *time.Time `json:"created_at,omitempty"`
	Mac                   string     `json:"mac,omitempty"`
	IP                    string     `json:"ip,omitempty"`
	ComputerName          string     `json:"computer_name,omitempty"`
	UserName              string     `json:"user_name,omitempty"`
	StrippedUserName      string     `json:"stripped_user_name,omitempty"`
	Realm                 string     `json:"realm,omitempty"`
	EventType             string     `json:"event_type,omitempty"`
	SwitchID              string     `json:"switch_id,omitempty"`
	SwitchMAC             string     `json:"switch_mac,omitempty"`
	SwitchIPAddress       string     `json:"switch_ip_address,omitempty"`
	RadiusSourceIPAddress string     `json:"radius_source_ip_address,omitempty"`
	CalledStationID       string     `json:"called_station_id,omitempty"`
	CallingStationID      string     `json:"calling_station_id,omitempty"`
	NASPortType           string     `json:"nas_port_type,omitempty"`
	SSID                  string     `json:"ssid,omitempty" gorm:"column:ssid"`
	NASPortID             string     `json:"nas_port_id,omitempty" gorm:"column:nas_port_id"`
	IfIndex               string     `json:"ifindex,omitempty" gorm:"column:ifindex"`
	NASPort               string     `json:"nas_port,omitempty" gorm:"column:nas_port"`
	ConnectionType        string     `json:"connection_type,omitempty"`
	NASIPAddress          string     `json:"nas_ip_address,omitempty" gorm:"column:nas_ip_address"`
	NASIdentifier         string     `json:"nas_identifier,omitempty" gorm:"column:nas_identifier"`
	AuthStatus            string     `json:"auth_status,omitempty"`
	Reason                string     `json:"reason,omitempty"`
	AuthType              string     `json:"auth_type,omitempty"`
	EAPType               string     `json:"eap_type,omitempty" gorm:"column:eap_type"`
	Role                  string     `json:"role,omitempty"`
	NodeStatus            string     `json:"node_status,omitempty"`
	Profile               string     `json:"profile,omitempty"`
	Source                string     `json:"source,omitempty"`
	AutoReg               string     `json:"auto_reg,omitempty"`
	IsPhone               string     `json:"is_phone,omitempty"`
	PFDomain              string     `json:"pf_domain,omitempty" gorm:"column:pf_domain"`
	UUID                  string     `json:"uuid,omitempty"`
	RadiusRequest         string     `json:"radius_request,omitempty"`
	RadiusReply           string     `json:"radius_reply,omitempty"`
	RequestTime           int        `json:"request_time,omitempty"`
	RadiusIP              string     `json:"radius_ip,omitempty"`

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
func NewRadiusAuditLogModel(dbp **gorm.DB, ctx *context.Context) *RadiusAuditLog {
	ret := &RadiusAuditLog{}
	ret.DB = *dbp
	ret.Ctx = ctx
	return ret
}
func (a RadiusAuditLog) Paginated(vars sql.Vars) (DBRes, error) {
	var res = DBRes{}
	var count int64

	a.DB.Model(&RadiusAuditLog{}).Count(&count)
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
		var items []RadiusAuditLog
		db := a.DB.Select(sqls.Select).Order(sqls.Order).Offset(sqls.Offset).Limit(sqls.Limit).Find(&items)
		if db.Error != nil {
			return DBRes{}, db.Error
		}
		for k, item := range items {
			items[k].RadiusRequest = urldecode(item.RadiusRequest)
			items[k].RadiusReply = urldecode(item.RadiusReply)
		}
		res.Items = items
	}
	return res, nil
}

func (a RadiusAuditLog) Search(vars sql.Vars) (DBRes, error) {
	res := DBRes{}
	sqls, err := vars.Sql(a)
	if err != nil {
		return res, err
	}

	var count int64
	var items []RadiusAuditLog
	a.DB.Model(&RadiusAuditLog{}).Where(sqls.Where.Query, sqls.Where.Values...).Count(&count)

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
		for k, item := range items {
			items[k].RadiusRequest = urldecode(item.RadiusRequest)
			items[k].RadiusReply = urldecode(item.RadiusReply)
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
		item.RadiusRequest = urldecode(item.RadiusRequest)
		item.RadiusReply = urldecode(item.RadiusReply)
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
