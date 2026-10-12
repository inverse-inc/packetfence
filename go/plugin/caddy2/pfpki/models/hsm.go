package models

import (
	"errors"
	"fmt"
	"strings"

	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/hsm"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

func NewHSMModel(pfpki *types.Handler) *HSM {
	HSM := &HSM{}

	HSM.DB = pfpki.DB
	HSM.Ctx = *pfpki.Ctx

	return HSM
}

// Config returns the PKCS#11 settings of the HSM.
func (h HSM) Config() hsm.Config {
	return hsm.Config{Module: h.Module, TokenLabel: h.TokenLabel, Pin: h.Pin}
}

// withoutPins clears the PINs before HSMs are returned by the API.
func withoutPins(hsms []HSM) []HSM {
	for i := range hsms {
		hsms[i].Pin = ""
	}
	return hsms
}

// New saves an HSM once its token can be opened with the given settings
// (hsm.Check logs the token out first, so the PIN is really checked).
func (h HSM) New() (types.Info, error) {
	Information := types.Info{}

	newHSM := HSM{Name: h.Name, Module: h.Module, TokenLabel: h.TokenLabel, Pin: h.Pin}
	if err := hsm.Check(newHSM.Config()); err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	if err := h.DB.Create(&newHSM).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New(dbError)
	}
	Information.Entries = withoutPins([]HSM{newHSM})

	return Information, nil
}

// GetByID retrieves the HSM by id
func (h HSM) GetByID(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var hsmdb []HSM
	if val, ok := params["id"]; ok {
		allFields := strings.Join(sql.SqlFields(h)[:], ",")
		h.DB.Select(allFields).Where("`id` = ?", val).First(&hsmdb)
	}
	Information.Entries = withoutPins(hsmdb)

	return Information, nil
}

// DelByID deletes the HSM, unless a CA key is held in it
func (h HSM) DelByID(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	val, ok := params["id"]
	if !ok {
		return Information, nil
	}
	var used int64
	h.DB.Model(&CA{}).Where("hsm_id = ?", val).Count(&used)
	if used > 0 {
		err := fmt.Errorf("the keys of %d CA(s) are held in this HSM", used)
		Information.Error = err.Error()
		return Information, err
	}
	var hsmdb HSM
	if err := h.DB.First(&hsmdb, val).Error; err == nil {
		hsm.Release(hsmdb.Config())
	}
	h.DB.Delete(&HSM{}, val)
	return Information, nil
}

// Search for the HSM
func (h HSM) Search(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	sql, err := vars.Sql(h)
	if err != nil {
		Information.Error = err.Error()
		return Information, errors.New(dbError)
	}
	var count int64
	h.DB.Model(&HSM{}).Where(sql.Where.Query, sql.Where.Values...).Count(&count)
	counter := int(count)

	Information.TotalCount = counter
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < counter {
		var hsmdb []HSM
		h.DB.Select(sql.Select).Where(sql.Where.Query, sql.Where.Values...).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&hsmdb)
		Information.Entries = withoutPins(hsmdb)
	}

	return Information, nil
}

// Update changes the module, token label or PIN of the HSM (the PIN is
// kept when none is given) once the token can be opened with them.
func (h HSM) Update(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var hsmdb HSM
	if err := h.DB.First(&hsmdb, params["id"]).Error; err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	previous := hsmdb.Config()
	hsmdb.Module = h.Module
	hsmdb.TokenLabel = h.TokenLabel
	if h.Pin != "" {
		hsmdb.Pin = h.Pin
	}
	// Close the context of the previous settings; Check closes every
	// context of the new token before trying the PIN (a token stays
	// logged in while a session is open, so any PIN would be accepted).
	hsm.Release(previous)
	if err := hsm.Check(hsmdb.Config()); err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	if err := h.DB.Save(&hsmdb).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New(dbError)
	}
	Information.Entries = withoutPins([]HSM{hsmdb})

	return Information, nil
}

// Paginated return the HSM list paginated
func (h HSM) Paginated(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	var count int64
	h.DB.Model(&HSM{}).Count(&count)
	counter := int(count)

	Information.TotalCount = counter
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < counter {
		sql, err := vars.Sql(h)
		if err != nil {
			Information.Error = err.Error()
			return Information, errors.New(dbError)
		}
		var hsmdb []HSM
		h.DB.Select(sql.Select).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&hsmdb)
		Information.Entries = withoutPins(hsmdb)
	}

	return Information, nil
}
