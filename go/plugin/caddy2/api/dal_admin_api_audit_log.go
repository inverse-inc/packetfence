package api

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"strconv"
	"strings"

	"github.com/inverse-inc/packetfence/go/dal/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"github.com/julienschmidt/httprouter"
	"gorm.io/gorm"
)

type AdminApiAuditLog struct {
	DBP **gorm.DB
	Ctx *context.Context
}

type RespBody struct {
	models.DBRes
	Status  int          `json:"status"`
	Errors  []models.Err `json:"errors,omitempty"`
	Message string       `json:"message,omitempty"`
}

func NewAdminApiAuditLog(ctx context.Context, dbp **gorm.DB) *AdminApiAuditLog {
	return &AdminApiAuditLog{
		DBP: dbp,
		Ctx: &ctx,
	}
}

func setError(body *RespBody, err error, status int) {
	body.Errors = append(body.Errors, models.Err{Message: err.Error()})
	body.Status = status
}

func outputResult(w http.ResponseWriter, body RespBody) {
	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	w.WriteHeader(body.Status)
	res, _ := json.Marshal(body)
	fmt.Fprintf(w, string(res))
}

func (a *AdminApiAuditLog) List(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	model := models.NewAdminApiAuditLogModel(a.DBP, a.Ctx)
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

func (a *AdminApiAuditLog) Search(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	model := models.NewAdminApiAuditLogModel(a.DBP, a.Ctx)
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

func (a *AdminApiAuditLog) GetItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	model := models.NewAdminApiAuditLogModel(a.DBP, a.Ctx)
	var body RespBody
	var err error
	body.Status = http.StatusOK

	id := p.ByName("id")
	_, err = strconv.Atoi(id)
	if err != nil {
		setError(&body, errors.New("invalid format for admin audit log entry ID"), http.StatusBadRequest)
		outputResult(w, body)
		return
	}

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

func (a *AdminApiAuditLog) DeleteItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	model := models.NewAdminApiAuditLogModel(a.DBP, a.Ctx)
	var body RespBody
	var err error
	body.Status = http.StatusOK

	id := p.ByName("id")
	_, err = strconv.Atoi(id)
	if err != nil {
		setError(&body, errors.New("invalid format for admin audit log entry ID"), http.StatusBadRequest)
		outputResult(w, body)
		return
	}

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

func (a *AdminApiAuditLog) UpdateItem(w http.ResponseWriter, r *http.Request, p httprouter.Params) {
	model := models.NewAdminApiAuditLogModel(a.DBP, a.Ctx)
	var body RespBody
	var err error
	body.Status = http.StatusOK

	id := p.ByName("id")
	nID, err := strconv.Atoi(id)
	if err != nil {
		setError(&body, errors.New("invalid format for admin audit log entry ID"), http.StatusBadRequest)
		outputResult(w, body)
		return
	}

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
	model.ID = int64(nID)
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
	body.Message = fmt.Sprintf("id %d updated", nID)
	outputResult(w, body)
}

func (a *AdminApiAuditLog) AddToRouter(r *httprouter.Router) {
	r.GET("/api/v1/admin_api_audit_logs", a.List)
	r.POST("/api/v1/admin_api_audit_logs/search", a.Search)
	r.GET("/api/v1/admin_api_audit_log/:id", a.GetItem)
}
