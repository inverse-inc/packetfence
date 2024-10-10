package models

import (
	"context"
	"errors"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"gorm.io/gorm"

	"strings"
)

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

// Wrix
func NewWrixModel(dbp **gorm.DB, ctx *context.Context) *Wrix {
	ret := &Wrix{}
	ret.DB = *dbp
	ret.Ctx = ctx
	return ret
}
func (a Wrix) Paginated(vars sql.Vars) (DBRes, error) {
	var res = DBRes{}
	var count int64

	a.DB.Model(&Wrix{}).Count(&count)
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

	var count int64
	var items []Wrix
	a.DB.Model(&Wrix{}).Where(sqls.Where.Query, sqls.Where.Values...).Count(&count)

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
