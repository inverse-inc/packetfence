package models

import (
	"encoding/hex"
	"errors"
	"fmt"
	"net/http"
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
	id, err := parseID(val)
	if err != nil {
		Information.Status = http.StatusBadRequest
		Information.Error = err.Error()
		return Information, err
	}
	var used int64
	h.DB.Model(&CA{}).Where("hsm_id = ?", id).Count(&used)
	if used > 0 {
		err := fmt.Errorf("the keys of %d CA(s) are held in this HSM", used)
		Information.Error = err.Error()
		return Information, err
	}
	var hsmdb HSM
	if err := h.DB.First(&hsmdb, id).Error; err == nil {
		hsm.Release(hsmdb.Config())
	}
	h.DB.Delete(&HSM{}, id)
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

// Update changes the module, token label or PIN of the HSM (the fields
// left out are kept) once the token can be opened with them.
func (h HSM) Update(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	id, err := parseID(params["id"])
	if err != nil {
		Information.Status = http.StatusBadRequest
		Information.Error = err.Error()
		return Information, err
	}
	var hsmdb HSM
	if err := h.DB.First(&hsmdb, id).Error; err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	previous := hsmdb.Config()
	// Fields left out of the request keep their stored value.
	if h.Module != "" {
		hsmdb.Module = h.Module
	}
	if h.TokenLabel != "" {
		hsmdb.TokenLabel = h.TokenLabel
	}
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
	// Another module or token must still hold the keys of the CAs of
	// this HSM, or they would stop signing.
	if hsmdb.Module != previous.Module || hsmdb.TokenLabel != previous.TokenLabel {
		if err := h.checkCAKeys(hsmdb); err != nil {
			hsm.Release(hsmdb.Config())
			Information.Error = err.Error()
			return Information, err
		}
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

// checkCAKeys checks that the token of hsmdb holds the key of every CA
// whose key is in this HSM: found by its id and matching the public key
// of the CA certificate.
func (h HSM) checkCAKeys(hsmdb HSM) error {
	var cas []CA
	if err := h.DB.Where("hsm_id = ?", hsmdb.ID).Find(&cas).Error; err != nil {
		return err
	}
	for _, ca := range cas {
		id, err := hex.DecodeString(ca.HsmKeyID)
		if err != nil {
			return fmt.Errorf("the key id of the CA %q is invalid: %w", ca.Cn, err)
		}
		signer, err := hsm.FindKey(hsmdb.Config(), id)
		if err != nil {
			return fmt.Errorf("the key of the CA %q is not in token %q: %w", ca.Cn, hsmdb.TokenLabel, err)
		}
		cert, err := ca.Certificate()
		if err != nil {
			return err
		}
		if err := sameKey(cert.PublicKey, signer.Public()); err != nil {
			return fmt.Errorf("the key of the CA %q in token %q: %w", ca.Cn, hsmdb.TokenLabel, err)
		}
	}
	return nil
}
