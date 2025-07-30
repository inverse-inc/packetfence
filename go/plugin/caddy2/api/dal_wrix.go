package api

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/go-chi/chi"
	"github.com/inverse-inc/packetfence/go/dal/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
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

func (a *Wrix) List() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
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
	})
}

func (a *Wrix) Search() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
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
	})
}

func (a *Wrix) GetItem() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		model := models.NewWrixModel(a.DBP, a.Ctx)
		var body RespBody
		var err error
		body.Status = http.StatusOK

		id := chi.URLParam(r, "id")

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

func (a *Wrix) DeleteItem() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		model := models.NewWrixModel(a.DBP, a.Ctx)
		var body RespBody
		var err error
		body.Status = http.StatusOK

		id := chi.URLParam(r, "id")

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

func (a *Wrix) UpdateItem() http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		model := models.NewWrixModel(a.DBP, a.Ctx)
		var body RespBody
		var err error
		body.Status = http.StatusOK

		id := chi.URLParam(r, "id")

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
	})
}

func (a *Wrix) AddToRouter(r *chi.Mux) {
	r.Get("/api/v1/wrixes", a.List())
	r.Post("/api/v1/wrixes/search", a.Search())
	r.Get("/api/v1/wrix/{id}", a.GetItem())
	r.Delete("/api/v1/wrix/{id}", a.DeleteItem())
	r.Patch("/api/v1/wrix/{id}", a.UpdateItem())
}
