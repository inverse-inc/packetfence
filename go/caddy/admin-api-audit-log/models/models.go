package models

import (
	"context"
	"errors"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/sql"
	"github.com/jinzhu/gorm"
	"strings"
	"time"
)

type Err struct {
	Message string `json:"message"`
}

type DBRes struct {
	Item       interface{} `json:"item,omitempty"`
	Items      interface{} `json:"items,omitempty"`
	Total      *int        `json:"total,omitempty"`
	NextCursor *int        `json:"nextCursor,omitempty"`
	PrevCursor *int        `json:"prevCursor,omitempty"`
}

const dbError = "a database error occured. see logs for details"

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

func (r RadiusAuditLog) TableName() string {
	return "radius_audit_log"
}

type Wrix struct {
	ID                        string `json:"id,omitempty" gorm:"primary_key"`
	ProviderIdentifier        string `json:"Provider_Identifier,omitempty" gorm:"column:Provider_Identifier"`
	LocationIdentifier        string `json:"Location_Identifier,omitempty" gorm:"column:Location_Identifier"`
	ServiceProviderBrand      string `json:"Service_Provider_Brand,omitempty" gorm:"column:Service_Provider_Brand"`
	LocationType              string `json:"Location_Type,omitempty" gorm:"column:Location_Type"`
	SubLocationType           string `json:"Sub_Location_Type,omitempty" gorm:"column:Sub_Location_Type"`
	EnglishLocationName       string `json:"English_Location_Name,omitempty" gorm:"column:English_Location_Name"`
	LocationAddress1          string `json:"Location_Address1,omitempty" gorm:"column:Location_Address1"`
	LocationAddress2          string `json:"Location_Address2,omitempty" gorm:"column:Location_Address2"`
	EnglishLocationCity       string `json:"English_Location_City,omitempty" gorm:"column:English_Location_City"`
	LocationZipPostalCode     string `json:"Location_Zip_Postal_Code,omitempty" gorm:"column:Location_Zip_Postal_Code"`
	LocationStateProvinceName string `json:"Location_State_Province_Name,omitempty" gorm:"column:Location_State_Province_Name"`
	LocationCountryName       string `json:"Location_Country_Name,omitempty" gorm:"column:Location_Country_Name"`
	LocationPhoneNumber       string `json:"Location_Phone_Number,omitempty" gorm:"column:Location_Phone_Number"`
	SSIDOpenAuth              string `json:"SSID_Open_Auth,omitempty" gorm:"column:SSID_Open_Auth"`
	SSIDBroadcasted           string `json:"SSID_Broadcasted,omitempty" gorm:"column:SSID_Broadcasted"`
	WEPKey                    string `json:"WEP_Key,omitempty" gorm:"column:WEP_Key"`
	WEPKeyEntryMethod         string `json:"WEP_Key_Entry_Method,omitempty" gorm:"column:WEP_Key_Entry_Method"`
	WEPKeySize                string `json:"WEP_Key_Size,omitempty" gorm:"column:WEP_Key_Size"`
	SSID1X                    string `json:"SSID_1X,omitempty" gorm:"column:SSID_1X"`
	SSID1XBroadcasted         string `json:"SSID_1X_Broadcasted,omitempty" gorm:"column:SSID_1X_Broadcasted"`
	SecurityProtocol1X        string `json:"Security_Protocol_1X,omitempty" gorm:"column:Security_Protocol_1X"`
	ClientSupport             string `json:"Client_Support,omitempty" gorm:"column:Client_Support"`
	RestrictedAccess          string `json:"Restricted_Access,omitempty" gorm:"column:Restricted_Access"`
	LocationURL               string `json:"Location_URL,omitempty" gorm:"column:Location_URL"`
	CoverageArea              string `json:"Coverage_Area,omitempty" gorm:"column:Coverage_Area"`
	OpenMonday                string `json:"Open_Monday,omitempty" gorm:"column:Open_Monday"`
	OpenTuesday               string `json:"Open_Tuesday,omitempty" gorm:"column:Open_Tuesday"`
	OpenWednesday             string `json:"Open_Wednesday,omitempty" gorm:"column:Open_Wednesday"`
	OpenThursday              string `json:"Open_Thursday,omitempty" gorm:"column:Open_Thursday"`
	OpenFriday                string `json:"Open_Friday,omitempty" gorm:"column:Open_Friday"`
	OpenSaturday              string `json:"Open_Saturday,omitempty" gorm:"column:Open_Saturday"`
	OpenSunday                string `json:"Open_Sunday,omitempty" gorm:"column:Open_Sunday"`
	Longitude                 string `json:"Longitude,omitempty" gorm:"column:Longitude"`
	Latitude                  string `json:"Latitude,omitempty" gorm:"column:Latitude"`
	UTCTimezone               string `json:"UTC_Timezone,omitempty" gorm:"column:UTC_Timezone"`
	MACAddress                string `json:"MAC_Address,omitempty" gorm:"column:MAC_Address"`

	DB  *gorm.DB         `json:"-" gorm:"-"`
	Ctx *context.Context `json:"-" gorm:"-"`
}

func (w Wrix) TableName() string {
	return "wrix"
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

// AuthLog
func NewAuthLogModel(db *gorm.DB, ctx *context.Context) *AuthLog {
	ret := &AuthLog{}
	ret.DB = db
	ret.Ctx = ctx
	return ret
}

func (a AuthLog) Paginated(vars sql.Vars) (DBRes, error) {
	var res = DBRes{}
	var count int

	a.DB.Model(&AuthLog{}).Count(&count)
	res.Total = &count
	res.PrevCursor = &vars.Cursor
	nextCursor := vars.Cursor + vars.Limit
	res.NextCursor = &nextCursor

	if vars.Cursor < count {
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

	var count int
	var items []AuthLog
	a.DB.Model(&AuthLog{}).Where(sqls.Where.Query, sqls.Where.Values...).Count(&count)

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

// RadacctLog
func NewRadacctLogModel(db *gorm.DB, ctx *context.Context) *RadacctLog {
	ret := &RadacctLog{}
	ret.DB = db
	ret.Ctx = ctx
	return ret
}
func (a RadacctLog) Paginated(vars sql.Vars) (DBRes, error) {
	var res = DBRes{}
	var count int

	a.DB.Model(&RadacctLog{}).Count(&count)
	res.Total = &count
	res.PrevCursor = &vars.Cursor
	nextCursor := vars.Cursor + vars.Limit
	res.NextCursor = &nextCursor

	if vars.Cursor < count {
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

	var count int
	var items []RadacctLog
	a.DB.Model(&RadacctLog{}).Where(sqls.Where.Query, sqls.Where.Values...).Count(&count)

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

// Wrix
func NewWrixModel(db *gorm.DB, ctx *context.Context) *Wrix {
	ret := &Wrix{}
	ret.DB = db
	ret.Ctx = ctx
	return ret
}
func (a Wrix) Paginated(vars sql.Vars) (DBRes, error) {
	var res = DBRes{}
	var count int

	a.DB.Model(&Wrix{}).Count(&count)
	res.Total = &count
	res.PrevCursor = &vars.Cursor
	nextCursor := vars.Cursor + vars.Limit
	res.NextCursor = &nextCursor

	if vars.Cursor < count {
		sqls, err := vars.Sql(a)
		if err != nil {
			return DBRes{}, err
		}
		var items []Wrix
		db := a.DB.Select(sqls.Select).Order(sqls.Order).Offset(sqls.Offset).Limit(sqls.Limit).Find(&items)
		if db.Error != nil {
			return DBRes{}, db.Error
		}
		res.Items = items
	}
	return res, nil
}

func (a Wrix) Search(vars sql.Vars) (DBRes, error) {
	res := DBRes{}
	sqls, err := vars.Sql(a)
	if err != nil {
		return res, err
	}

	var count int
	var items []Wrix
	a.DB.Model(&Wrix{}).Where(sqls.Where.Query, sqls.Where.Values...).Count(&count)

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

func (a Wrix) GetByID(id string) (DBRes, error) {
	res := DBRes{}
	var item Wrix

	allFields := strings.Join(sql.SqlFields(a)[:], ",")
	db := a.DB.Select(allFields).Where("`id` = ?", id).First(&item)
	if db.Error == nil {
		res.Item = item
	}
	return res, db.Error
}

func (a Wrix) Delete(id string) (DBRes, error) {
	res := DBRes{}
	var item Wrix
	db := a.DB.Where("`id` = ?", id).Find(&item)
	if db.Error != nil {
		return res, db.Error
	}
	err := a.DB.Unscoped().Delete(item).Error
	return res, err
}

func (a Wrix) Update() (DBRes, error) {
	var item Wrix
	res := DBRes{}

	err := a.DB.Model(&Wrix{}).Where("id = ?", a.ID).Updates(a).Error

	if err != nil {
		return DBRes{}, err
	}
	allFields := strings.Join(sql.SqlFields(a)[:], ",")
	a.DB.Select(allFields).Where("`id` = ?", a.ID).First(&item)

	res.Item = item
	return res, nil
}
