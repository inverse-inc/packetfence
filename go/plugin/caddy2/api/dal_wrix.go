package api

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"

	"github.com/inverse-inc/packetfence/go/dal/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"github.com/julienschmidt/httprouter"
	"gorm.io/gorm"
)

type Wrix struct {
	DBP **gorm.DB
	Ctx *context.Context
}

func NewWrix(ctx context.Context, dbp **gorm.DB) *Wrix {
	return &Wrix{
		DBP: dbp,
		Ctx: &ctx,
	}
}

func (a *Wrix) List(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	model := models.NewWrixModel(a.DBP, a.Ctx)
	var body RespBody
	var err error
	body.Status = http.StatusOK

	vars, err := types.DecodeUrlQuery(r)
	if err != nil {
		setError(&body, err, http.StatusBadRequest)
		outputResult(w, body)
		return
	}

	body.DBRes, err = model.Paginated(vars)
	if err != nil {
		setError(&body, err, http.StatusInternalServerError)
		outputResult(w, body)
		return
	}

	outputResult(w, body)
}

func (a *Wrix) Search(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	model := models.NewWrixModel(a.DBP, a.Ctx)
	var body RespBody
	var err error
	body.Status = http.StatusOK

	var vars sql.Vars
	err = vars.DecodeBodyJson(r)
	if err != nil {
		setError(&body, err, http.StatusBadRequest)
		outputResult(w, body)
		return
	}

	body.DBRes, err = model.Search(vars)
	if err != nil {
		setError(&body, err, http.StatusNotFound)
		outputResult(w, body)
		return
	}
	outputResult(w, body)
}

func (a *Wrix) GetItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	model := models.NewWrixModel(a.DBP, a.Ctx)
	var body RespBody
	var err error
	body.Status = http.StatusOK

	id := p.ByName("id")

	body.DBRes, err = model.GetByID(id)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			setError(&body, err, http.StatusNotFound)
		} else {
			setError(&body, err, http.StatusInternalServerError)
		}
		outputResult(w, body)
		return
	}
	outputResult(w, body)
}

func (a *Wrix) DeleteItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	model := models.NewWrixModel(a.DBP, a.Ctx)
	var body RespBody
	var err error
	body.Status = http.StatusOK

	id := p.ByName("id")

	body.DBRes, err = model.Delete(id)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			setError(&body, err, http.StatusNotFound)
		} else {
			setError(&body, err, http.StatusInternalServerError)
		}
		outputResult(w, body)
		return
	}

	body.Message = fmt.Sprintf("Deleted %s successfully", id)
	outputResult(w, body)
}

func (a *Wrix) UpdateItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	model := models.NewWrixModel(a.DBP, a.Ctx)
	var body RespBody
	var err error
	body.Status = http.StatusOK

	id := p.ByName("id")

	body.DBRes, err = model.GetByID(id)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			setError(&body, err, http.StatusNotFound)
		} else {
			setError(&body, err, http.StatusInternalServerError)
		}
		outputResult(w, body)
		return
	}

	payload, err := ioutil.ReadAll(r.Body)
	if err != nil {
		setError(&body, err, http.StatusBadRequest)
		outputResult(w, body)
		return
	}
	err = json.Unmarshal(payload, &model)
	model.ID = id
	if err != nil {
		setError(&body, err, http.StatusUnprocessableEntity)
		outputResult(w, body)
		return
	}

	body.DBRes, err = model.Update()

	if err != nil {
		setError(&body, err, http.StatusUnprocessableEntity)
		outputResult(w, body)
		return
	}
	body.Message = fmt.Sprintf("id %s updated", id)
	outputResult(w, body)
}

func (a *Wrix) AddToRouter(r *httprouter.Router) {
	r.GET("/api/v1/wrixes", a.List)
	r.POST("/api/v1/wrixes/search", a.Search)
	r.GET("/api/v1/wrix/:id", a.GetItem)
	r.DELETE("/api/v1/wrix/:id", a.DeleteItem)
	r.PATCH("/api/v1/wrix/:id", a.UpdateItem)
}
