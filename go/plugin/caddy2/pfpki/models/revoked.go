package models

import (
	"strings"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

func NewRevokedCertModel(pfpki *types.Handler) *RevokedCert {
	RevokedCert := &RevokedCert{}

	RevokedCert.DB = pfpki.DB
	RevokedCert.Ctx = *pfpki.Ctx

	return RevokedCert
}

func (c RevokedCert) GetByID(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var revokedcertdb []RevokedCert
	if val, ok := params["id"]; ok {
		allFields := strings.Join(sql.SqlFields(c)[:], ",")
		c.DB.Select(allFields).Where("`id` = ?", val).First(&revokedcertdb)
	}
	Information.Entries = revokedcertdb

	return Information, nil
}

func (c RevokedCert) Paginated(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	var count int64
	c.DB.Model(&RevokedCert{}).Count(&count)
	counter := int(count)
	Information.TotalCount = counter
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < counter {
		sql, err := vars.Sql(c)
		if err != nil {
			Information.Error = err.Error()
			return Information, err
		}
		var revokedcertdb []RevokedCert
		result := c.DB.Select(sql.Select).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&revokedcertdb)
		if result.Error != nil {
			Information.Error = result.Error.Error()
			return Information, err
		}

		Information.Entries = revokedcertdb
	}

	return Information, nil
}

func (c RevokedCert) Search(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	sql, err := vars.Sql(c)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	var count int64
	c.DB.Model(&Cert{}).Where(sql.Where.Query, sql.Where.Values...).Count(&count)
	counter := int(count)
	Information.TotalCount = counter
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < counter {
		var revokedcertdb []RevokedCert
		c.DB.Select(sql.Select).Where(sql.Where.Query, sql.Where.Values...).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&revokedcertdb)
		Information.Entries = revokedcertdb
	}

	return Information, nil
}
