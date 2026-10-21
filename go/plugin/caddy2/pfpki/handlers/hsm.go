package handlers

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"

	"github.com/inverse-inc/packetfence/go/admin_api_audit_log"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

// GetSetHSM lists the HSMs (GET) or adds one (POST).
func GetSetHSM(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		o := models.NewHSMModel(pfpki)
		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog = nil

		Error := types.Errors{Status: 0}

		switch req.Method {
		case "GET":
			vars, err := types.DecodeUrlQuery(req)
			Information.Status = http.StatusOK
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
				break
			}
			Information, err = o.Paginated(vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
				break
			}

		case "POST":
			body, err := io.ReadAll(req.Body)
			Information.Status = http.StatusCreated
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
				break
			}
			if err = json.Unmarshal(body, &o); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
				break
			}
			if Information, err = o.New(); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusUnprocessableEntity
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, body, "pfpki.SetHSM")

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}

// SearchHSM searches the HSMs.
func SearchHSM(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		o := models.NewHSMModel(pfpki)
		var Information types.Info
		var err error

		Error := types.Errors{Status: 0}

		switch req.Method {
		case "POST":
			Information.Status = http.StatusOK
			var vars sql.Vars
			if err := vars.DecodeBodyJson(req); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
				break
			}
			Information, err = o.Search(vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
				break
			}
		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req, nil)
	})
}

// HSMByID gets (GET), updates (PATCH) or deletes (DELETE) an HSM.
func HSMByID(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		o := models.NewHSMModel(pfpki)
		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog

		Error := types.Errors{Status: 0}
		vars := types.Params(req, "id")

		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			Information, err = o.GetByID(vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
				break
			}

		case "PATCH":
			Information.Status = http.StatusOK
			body, err := io.ReadAll(req.Body)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
				break
			}
			if err = json.Unmarshal(body, &o); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
				break
			}
			if Information, err = o.Update(vars); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusUnprocessableEntity
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, body, "pfpki.UpdateHSM")

		case "DELETE":
			Information.Status = http.StatusOK
			if Information, err = o.DelByID(vars); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusConflict
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, nil, "pfpki.DeleteHSM")

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}
