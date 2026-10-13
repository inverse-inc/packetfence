package models

import (
	"errors"
	"strings"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

func NewSCEPServerModel(pfpki *types.Handler) *SCEPServer {
	SCEPServer := &SCEPServer{}

	SCEPServer.DB = pfpki.DB
	SCEPServer.Ctx = *pfpki.Ctx

	return SCEPServer
}

func (s SCEPServer) New() (types.Info, error) {
	Information := types.Info{}

	newSCEP := SCEPServer{Name: s.Name, URL: s.URL, SharedSecret: s.SharedSecret}
	if err := s.DB.Create(&newSCEP).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New(dbError)
	}
	Information.Entries = []SCEPServer{newSCEP}

	return Information, nil
}

// GetByID retreive the SCEPServer by id
func (s SCEPServer) GetByID(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var scepserverdb []SCEPServer
	if val, ok := params["id"]; ok {
		allFields := strings.Join(sql.SqlFields(s)[:], ",")
		s.DB.Select(allFields).Where("`id` = ?", val).First(&scepserverdb)
	}
	Information.Entries = scepserverdb

	return Information, nil
}

// GetByID retreive the SCEPServer by id
func (s SCEPServer) DelByID(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var scepserverdb []SCEPServer
	if val, ok := params["id"]; ok {
		s.DB.Delete(&SCEPServer{}, val)
	}
	Information.Entries = scepserverdb
	return Information, nil
}

// Search for the SCEPServer
func (s SCEPServer) Search(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	sql, err := vars.Sql(s)
	if err != nil {
		Information.Error = err.Error()
		return Information, errors.New(dbError)
	}
	var count int64
	s.DB.Model(&SCEPServer{}).Where(sql.Where.Query, sql.Where.Values...).Count(&count)
	counter := int(count)

	Information.TotalCount = counter
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < counter {
		var scepserverdb []SCEPServer
		s.DB.Select(sql.Select).Where(sql.Where.Query, sql.Where.Values...).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&scepserverdb)
		Information.Entries = scepserverdb
	}

	return Information, nil
}

func (s SCEPServer) Update() (types.Info, error) {
	Information := types.Info{}
	if err := s.DB.Model(&SCEPServer{}).Where("name = ?", s.Name).Updates(map[string]interface{}{"url": s.URL, "shared_secret": s.SharedSecret}).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New(dbError)
	}
	var scepserverdb []SCEPServer
	s.DB.Where("name = ?", s.Name).First(&scepserverdb)
	Information.Entries = scepserverdb

	return Information, nil
}

// Paginated return the SCEPServer list paginated
func (s SCEPServer) Paginated(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	var count int64
	s.DB.Model(&CA{}).Count(&count)
	counter := int(count)

	Information.TotalCount = counter
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < counter {
		sql, err := vars.Sql(s)
		if err != nil {
			Information.Error = err.Error()
			return Information, errors.New(dbError)
		}
		var scepserverdb []SCEPServer
		s.DB.Select(sql.Select).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&scepserverdb)
		Information.Entries = scepserverdb
	}

	return Information, nil
}
