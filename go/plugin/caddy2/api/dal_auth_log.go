package api

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/inverse-inc/packetfence/go/dal/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
	"gorm.io/gorm"
)

type AuthLog struct {
	DBP **gorm.DB
	Ctx *context.Context
}

func NewAuthLog(ctx context.Context, dbp **gorm.DB) *AuthLog {
	return &AuthLog{
		DBP: dbp,
		Ctx: &ctx,
	}
}

func (a *AuthLog) List() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		model := models.NewAuthLogModel(a.DBP, a.Ctx)
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
	})
}

func (a *AuthLog) Search() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		model := models.NewAuthLogModel(a.DBP, a.Ctx)
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
	})
}

func (a *AuthLog) GetItem() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		model := models.NewAuthLogModel(a.DBP, a.Ctx)
		var body RespBody
		var err error
		body.Status = http.StatusOK

		id := chi.URLParam(r, "id")
		_, err = strconv.Atoi(id)
		if err != nil {
			setError(&body, errors.New("invalid format for auth log entry ID"), http.StatusBadRequest)
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
	})
}

func (a *AuthLog) DeleteItem() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		model := models.NewAuthLogModel(a.DBP, a.Ctx)
		var body RespBody
		var err error
		body.Status = http.StatusOK

		id := chi.URLParam(r, "id")
		_, err = strconv.Atoi(id)
		if err != nil {
			setError(&body, errors.New("invalid format for auth log entry ID"), http.StatusBadRequest)
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
	})
}

func (a *AuthLog) UpdateItem() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		model := models.NewAuthLogModel(a.DBP, a.Ctx)
		var body RespBody
		var err error
		body.Status = http.StatusOK

		id := chi.URLParam(r, "id")
		nID, err := strconv.Atoi(id)
		if err != nil {
			setError(&body, errors.New("invalid format for auth log entry ID"), http.StatusBadRequest)
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

		payload, err := io.ReadAll(r.Body)
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
	})
}

func (a *AuthLog) AddToRouter(r *chi.Mux) {
	r.Get("/api/v1/auth_logs", a.List())
	r.Post("/api/v1/auth_logs/search", a.Search())
	r.Get("/api/v1/auth_log/{id}", a.GetItem())
}
