package handlers

import (
	"bytes"
	"crypto/sha1"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/admin_api_audit_log"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/ocsp"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/ocspresponder"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/scep"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

// numericID matches a certificate id, as opposed to a CN
var numericID = regexp.MustCompile(`^[0-9]+$`)

// MaxRequestBody is the upper bound for request bodies on the pfpki API.
// JSON CRUD payloads are well under 64 KiB; SCEP PKIOperation messages and
// CSRs run a few KB at most. 1 MiB is generous and still prevents a single
// streaming client from exhausting memory.
const MaxRequestBody = 1 << 20

// LimitRequestBody is a chi-compatible middleware that wraps req.Body with
// http.MaxBytesReader. Reads past the limit return an error and (for HTTP/1)
// terminate the connection.
func LimitRequestBody(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Body != nil {
			r.Body = http.MaxBytesReader(w, r.Body, MaxRequestBody)
		}
		next.ServeHTTP(w, r)
	})
}

func SearchCA(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCAModel(pfpki)
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
			Information.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, nil)
	})
}

func GetSetCA(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		o := models.NewCAModel(pfpki)
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
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, body, "pfpki.SetCA")

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}

func makeAdminApiAuditLog(pfpki *types.Handler, req *http.Request, Information types.Info, body []byte, action string) *admin_api_audit_log.AdminApiAuditLog {
	vars := types.Params(req, "id")
	log := &admin_api_audit_log.AdminApiAuditLog{
		UserName: req.Header.Get("X-PacketFence-Username"),
		Action:   action,
		ObjectId: vars["id"],
		Url:      req.URL.Path,
		Method:   req.Method,
		Status:   int16(Information.Status),
	}
	if body != nil {
		log.Request, _ = admin_api_audit_log.MaskSecrets(
			string(body),
			"scep_challenge_password",
			"est_password",
			"shared_secret",
			"pin",
		)
	}
	return log
}

func ResignCA(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		o := models.NewCAModel(pfpki)
		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog

		Error := types.Errors{Status: 0}

		switch req.Method {

		case "POST":
			vars := types.Params(req, "id")
			Information.Status = http.StatusCreated
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
			if Information, err = o.Resign(vars); err != nil {
				Error.Message = err.Error()
				Error.Status = idErrorStatus(err, http.StatusUnprocessableEntity)
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, body, "pfpki.ResignCA")

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}

func GenerateCSR(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		o := models.NewCAModel(pfpki)
		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog

		Error := types.Errors{Status: 0}

		switch req.Method {

		case "POST":
			vars := types.Params(req, "id")
			Information.Status = http.StatusCreated
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
			if Information, err = o.GenerateCSR(vars); err != nil {
				Error.Message = err.Error()
				Error.Status = idErrorStatus(err, http.StatusUnprocessableEntity)
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, body, "pfpki.GenerateCSR")

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}

func CAByID(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		o := models.NewCAModel(pfpki)
		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog

		Error := types.Errors{Status: 0}

		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars := types.Params(req, "id")
			Information, err = o.GetByID(vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
				break
			}

		case "PATCH":
			vars := types.Params(req, "id")
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
				Error.Status = idErrorStatus(err, http.StatusUnprocessableEntity)
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, body, "pfpki.UpdateCA")

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}

func FixCA(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		o := models.NewCAModel(pfpki)
		var Information types.Info
		var err error

		Error := types.Errors{Status: 0}

		Information, err = o.Fix()
		if err != nil {
			Error.Message = err.Error()
			Error.Status = http.StatusNotFound
		}
		Information.Status = http.StatusOK
		manageAnswer(Information, Error, pfpki, res, req, nil)
	})
}

func GetSetProfile(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewProfileModel(pfpki)

		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog

		Error := types.Errors{Status: 0}

		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars, err := types.DecodeUrlQuery(req)
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
			Information.Status = http.StatusCreated
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
			if Information, err = o.New(); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusUnprocessableEntity
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, body, "pfpki.SetProfile")

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}

func SearchProfile(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewProfileModel(pfpki)
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
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, nil)
	})
}

func GetProfileByID(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewProfileModel(pfpki)

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
				Error.Status = idErrorStatus(err, http.StatusUnprocessableEntity)
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, body, "pfpki.UpdateProfile")

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}

func GetSetCert(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCertModel(pfpki)

		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog

		Error := types.Errors{Status: 0}

		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars, err := types.DecodeUrlQuery(req)
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
			Information.Status = http.StatusCreated
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
			if Information, err = o.New(); err != nil {
				Error.Message = err.Error()
				Error.Status = Information.Status
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, body, "pfpki.SetCert")

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}

func SearchCert(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCertModel(pfpki)
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
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, nil)
	})
}

func GetCertByID(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCertModel(pfpki)
		var Information types.Info
		var err error

		Error := types.Errors{Status: 0}

		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars := types.Params(req, "id", "cn")
			Information, err = o.GetByID(vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
				break
			}

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, nil)
	})
}

func DownloadCert(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCertModel(pfpki)
		var Information types.Info
		var err error

		Error := types.Errors{Status: 0}

		vars := types.Params(req, "id", "cn", "profile")
		if numericID.MatchString(vars["id"]) {
			delete(vars, "cn")
		} else {
			vars["cn"] = vars["id"]
			delete(vars, "id")
		}
		switch req.Method {
		case "POST":
			// The password is in the body, so it doesn't end up in the access logs
			var body struct {
				Password string `json:"password"`
			}
			req.Body = http.MaxBytesReader(res, req.Body, 4096)
			if err = json.NewDecoder(req.Body).Decode(&body); err != nil && !errors.Is(err, io.EOF) {
				var tooLarge *http.MaxBytesError
				if errors.As(err, &tooLarge) {
					Error.Message = "The request body is too large"
					Error.Status = http.StatusRequestEntityTooLarge
				} else {
					Error.Message = `The request body must be a JSON object with a "password": ` + err.Error()
					Error.Status = http.StatusBadRequest
				}
				break
			}
			if body.Password == "" {
				Error.Message = "A password is required"
				Error.Status = http.StatusBadRequest
				break
			}
			vars["password"] = body.Password
			Information.Status = http.StatusOK
			Information, err = o.Download(vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = idErrorStatus(err, http.StatusNotFound)
				break
			}

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, nil)
	})
}

func EmailCert(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCertModel(pfpki)
		var Information types.Info
		var err error

		Error := types.Errors{Status: 0}

		switch req.Method {
		// POST, as it returns the password of the PKCS#12 it emails
		case "POST":
			vars := types.Params(req, "id", "profile", "cn")
			if !numericID.MatchString(vars["id"]) {
				Error.Message = "Invalid certificate id"
				Error.Status = http.StatusBadRequest
				break
			}
			Information.Status = http.StatusOK
			// Optional admin-supplied password, in the JSON body
			// ({"password": "..."}). It is renamed to "mail_password" so
			// Cert.Download doesn't confuse it with the binary-download
			// trigger.
			var body struct {
				Password string `json:"password"`
			}
			raw, rerr := io.ReadAll(req.Body)
			if rerr == nil && len(bytes.TrimSpace(raw)) > 0 {
				rerr = json.Unmarshal(raw, &body)
			}
			if rerr != nil {
				err = rerr
				Error.Message = "invalid request body: " + rerr.Error()
				Error.Status = http.StatusBadRequest
				break
			}
			if pw := body.Password; pw != "" {
				vars["mail_password"] = pw
			}
			Information, err = o.Download(vars)
			if err != nil {
				Error.Message = err.Error()
				// 404 for a certificate that can't be found or
				// loaded, not for a mail server that can't be reached
				Error.Status = idErrorStatus(err, http.StatusNotFound)
				if errors.Is(err, models.ErrCertMail) {
					Error.Status = http.StatusInternalServerError
				}
				break
			}

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, nil)
	})
}

func RevokeCert(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCertModel(pfpki)
		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog = nil

		Error := types.Errors{Status: 0}

		vars := types.Params(req, "id", "cn", "profile", "reason")
		if _, ok := vars["cn"]; ok {
			delete(vars, "id")
		}
		switch req.Method {
		case "DELETE":
			Information.Status = http.StatusOK
			Information, err = o.Revoke(vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusUnprocessableEntity
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, nil, "pfpki.RevokeCert")

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}

func ResignCert(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		o := models.NewCertModel(pfpki)
		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog

		Error := types.Errors{Status: 0}

		switch req.Method {

		case "POST":
			vars := types.Params(req, "id")
			// A certificate is re-signed by its numeric id only. This also
			// keeps POST /resign/download, which chi routes here rather than to
			// the download, from re-signing anything.
			if !numericID.MatchString(vars["id"]) {
				Error.Message = "Invalid certificate id"
				Error.Status = http.StatusBadRequest
				break
			}
			Information.Status = http.StatusCreated
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
			if Information, err = o.Resign(vars); err != nil {
				Error.Message = err.Error()
				Error.Status = idErrorStatus(err, http.StatusUnprocessableEntity)
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, body, "pfpki.ResignCert")

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}

func GetRevoked(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewRevokedCertModel(pfpki)

		var Information types.Info
		var err error

		Error := types.Errors{Status: 0}
		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars, err := types.DecodeUrlQuery(req)
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

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, nil)
	})
}

func SearchRevoked(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewRevokedCertModel(pfpki)
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
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, nil)
	})
}

func GetRevokedByID(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewRevokedCertModel(pfpki)
		var Information types.Info
		var err error

		Error := types.Errors{Status: 0}
		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars := types.Params(req, "id")
			Information, err = o.GetByID(vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
				break
			}

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, nil)
	})
}

// ProcessCloudRevocations triggers a sweep of every cloud-enabled
// profile's revocation queue (currently only Intune's
// CARevocationRequests). Safe to call manually after a SCEP enrollment
// fails with "Certificate with this Subject already exist", or on a
// schedule (e.g. via a pfcron job).
func ProcessCloudRevocations(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCertModel(pfpki)
		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog = nil

		Error := types.Errors{Status: 0}
		switch req.Method {
		// POST only: it changes state, here and in the cloud service.
		case "POST":
			Information.Status = http.StatusOK
			Information, err = o.ProcessCloudRevocations()
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, nil, "pfpki.ProcessCloudRevocations")
		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}

func CheckRenewal(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCertModel(pfpki)
		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog = nil

		Error := types.Errors{Status: 0}
		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars := types.Params(req, "id", "reason")
			Information, err = o.CheckRenewal(vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, nil, "pfpki.CheckRenewal")

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}

func SignCSR(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCsrModel(pfpki)

		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog

		Error := types.Errors{Status: 0}
		vars := types.Params(req, "id")
		switch req.Method {

		case "POST":
			Information.Status = http.StatusCreated
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
			if Information, err = o.New(vars); err != nil {
				Error.Message = err.Error()
				Error.Status = Information.Status
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, body, "pfpki.SignCSR")

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}

// idErrorStatus answers 400 when the {id} of the URL isn't a number,
// and status for any other error.
func idErrorStatus(err error, status int) int {
	if errors.Is(err, models.ErrInvalidID) {
		return http.StatusBadRequest
	}
	return status
}

func manageAnswer(Information types.Info, Error types.Errors, pfpki *types.Handler, res http.ResponseWriter, req *http.Request, alog *admin_api_audit_log.AdminApiAuditLog) {
	var err error

	if Error.Status != 0 {
		res.Header().Set("Content-Type", "application/json; charset=UTF-8")
		res.WriteHeader(Error.Status)
		log.LoggerWContext(*pfpki.Ctx).Error(Information.Error)
		if err := json.NewEncoder(res).Encode(&Error); err != nil {
			fmt.Println(err)
		}
		return
	}
	if err != nil {
		log.LoggerWContext(*pfpki.Ctx).Info(err.Error())
		if Information.Status >= 400 {
			Information.Error = http.StatusText(Information.Status)
		}
	}

	if Information.Status < 300 {
		if alog != nil {
			alog.Add(pfpki.DB)
		}
	}

	switch ContentType := Information.ContentType; ContentType {

	case "application/x-pkcs12":
		res.Header().Set("Content-Type", "application/x-pkcs12")
		res.Header().Set("Content-Disposition", "attachment; filename=certificate.p12")
		res.WriteHeader(http.StatusOK)
		io.Copy(res, bytes.NewReader(Information.Raw))

	default:
		Information.ContentType = "application/json; charset=UTF-8"
		res.Header().Set("Content-Type", "application/json; charset=UTF-8")
		res.WriteHeader(http.StatusOK)
		if err := json.NewEncoder(res).Encode(&Information); err != nil {
			panic(err)
		}
	}
}

// ManageOcsp answers OCSP requests (RFC 6960 appendix A.1): the DER
// request is the body of a POST, or, for a GET, the rest of the path after
// /pki/ocsp/, base64 then URL encoded. A GET answer carries the cache
// headers of RFC 5019 section 6.2, so proxies and clients can keep it
// until nextUpdate. A request it can't answer gets the unsigned OCSP
// response of its error status (malformedRequest, unauthorized,
// internalError, tryLater); HTTP errors are left for what isn't an OCSP
// request: a POST of another Content-Type (400) or another method (405).
func ManageOcsp(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		logger := log.LoggerWContext(*pfpki.Ctx)
		logger.Info(fmt.Sprintf("Got %s request from %s", req.Method, req.RemoteAddr))

		var rawreq []byte
		switch req.Method {
		case http.MethodPost:
			if req.Header.Get("Content-Type") != "application/ocsp-request" {
				logger.Info("OCSP POST requires the Content-Type application/ocsp-request")
				res.WriteHeader(http.StatusBadRequest)
				return
			}
			var err error
			if rawreq, err = io.ReadAll(req.Body); err != nil {
				logger.Info(err.Error())
				res.WriteHeader(http.StatusBadRequest)
				return
			}
		case http.MethodGet:
			var err error
			if rawreq, err = ocspRequestFromPath(chi.URLParam(req, "*")); err != nil {
				// A GET to the OCSP URL is an OCSP request: answer it
				// as one that doesn't parse.
				writeOCSPError(res, pfpki, &ocspresponder.Error{Status: ocsp.Malformed, Err: fmt.Errorf("OCSP GET: %w", err)})
				return
			}
		default:
			logger.Info("Unsupported request method")
			res.WriteHeader(http.StatusMethodNotAllowed)
			return
		}

		// parse request, verify, create response
		answer, err := Responder(pfpki).Respond(rawreq)
		if err != nil {
			writeOCSPError(res, pfpki, err)
			return
		}
		res.Header().Set("Content-Type", "application/ocsp-response")
		if req.Method == http.MethodGet {
			setOCSPCacheHeaders(res.Header(), answer)
		}
		logger.Info("Writing response")
		res.Write(answer.DER)
	})
}

// writeOCSPError answers an OCSP request the responder can't answer with
// the unsigned OCSP response of its error status (RFC 6960 section 2.3),
// with HTTP 200 and no cache headers: validators act on the OCSP status,
// and caches mustn't keep it.
func writeOCSPError(res http.ResponseWriter, pfpki *types.Handler, err error) {
	logger := log.LoggerWContext(*pfpki.Ctx)
	status, der := ocspresponder.ErrorResponse(err)
	if status == ocsp.Malformed || status == ocsp.Unauthorized {
		logger.Info("OCSP request refused: " + err.Error())
	} else {
		logger.Error("OCSP request failed: " + err.Error())
	}
	res.Header().Set("Content-Type", "application/ocsp-response")
	res.Header().Set("Cache-Control", "no-store")
	res.Write(der)
}

// ocspRequestFromPath decodes the request of an OCSP GET: the DER request,
// base64 encoded, then URL encoded, as the rest of the path after
// /pki/ocsp/. chi hands the tail of the path as the client sent it, so the
// '/', '+' and '=' of the base64 may still be percent-encoded; a decoded
// tail is left as is, since base64 has no '%'. An OCSP URL configured
// with a trailing slash makes the client send /pki/ocsp//<base64>: the
// leading slashes are dropped, since a DER OCSPRequest starts with a
// SEQUENCE (0x30), which is 'M' in base64, never '/'.
func ocspRequestFromPath(tail string) ([]byte, error) {
	b64, err := url.PathUnescape(tail)
	if err != nil {
		return nil, err
	}
	b64 = strings.TrimLeft(b64, "/")
	if b64 == "" {
		return nil, errors.New("no OCSP request in the path")
	}
	return base64.StdEncoding.DecodeString(b64)
}

// setOCSPCacheHeaders adds the headers of RFC 5019 section 6.2 to the
// answer of an OCSP GET: the response is valid from Last-Modified
// (thisUpdate) to Expires (nextUpdate), and its ETag is the SHA-1 of its
// bytes.
func setOCSPCacheHeaders(h http.Header, a *ocspresponder.Answer) {
	maxAge := int(time.Until(a.NextUpdate).Seconds())
	if maxAge < 0 {
		maxAge = 0
	}
	sum := sha1.Sum(a.DER)
	h.Set("Last-Modified", a.ThisUpdate.UTC().Format(http.TimeFormat))
	h.Set("Expires", a.NextUpdate.UTC().Format(http.TimeFormat))
	h.Set("ETag", `"`+hex.EncodeToString(sum[:])+`"`)
	h.Set("Cache-Control", fmt.Sprintf("max-age=%d, public, no-transform, must-revalidate", maxAge))
}

func ManageSCEP(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		log.LoggerWContext(*pfpki.Ctx).Info(fmt.Sprintf("Got %s request from %s", req.Method, req.RemoteAddr))
		scep.ScepHandler(pfpki, res, req)
	})
}

// Responder returns the OCSP responder of the PKI.
func Responder(pfpki *types.Handler) *ocspresponder.OCSPResponder {
	return &ocspresponder.OCSPResponder{Handler: pfpki}
}

func SearchSCEPServer(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewSCEPServerModel(pfpki)
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
			Information.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, nil)
	})
}

func SCEPServerByID(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		o := models.NewSCEPServerModel(pfpki)
		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog

		Error := types.Errors{Status: 0}

		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars := types.Params(req, "id")
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
			if Information, err = o.Update(); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusUnprocessableEntity
				break
			}
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, body, "pfpki.UpdateCA")
		case "DELETE":
			Information.Status = http.StatusOK
			vars := types.Params(req, "id")
			Information, err = o.DelByID(vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = idErrorStatus(err, http.StatusNotFound)
				break
			}

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}

func GetSetSCEPServer(pfpki *types.Handler) http.HandlerFunc {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		o := models.NewSCEPServerModel(pfpki)
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
			auditLog = makeAdminApiAuditLog(pfpki, req, Information, body, "pfpki.SetCA")

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
			break
		}
		manageAnswer(Information, Error, pfpki, res, req, auditLog)
	})
}
