package handlers

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"regexp"

	"github.com/gorilla/mux"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/packetfence/go/admin_api_audit_log"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/models"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/ocspresponder"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/scep"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/plugin/caddy2/pfpki/types"
)

func SearchCA(pfpki *types.Handler) http.Handler {
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

func GetSetCA(pfpki *types.Handler) http.Handler {
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
			body, err := ioutil.ReadAll(req.Body)
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
	vars := mux.Vars(req)
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
		)
	}
	return log
}

func ResignCA(pfpki *types.Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		o := models.NewCAModel(pfpki)
		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog

		Error := types.Errors{Status: 0}

		switch req.Method {

		case "POST":
			vars := mux.Vars(req)
			Information.Status = http.StatusCreated
			body, err := ioutil.ReadAll(req.Body)
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
				Error.Status = http.StatusUnprocessableEntity
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

func GetCAByID(pfpki *types.Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		o := models.NewCAModel(pfpki)
		var Information types.Info
		var err error

		Error := types.Errors{Status: 0}

		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars := mux.Vars(req)
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

func FixCA(pfpki *types.Handler) http.Handler {
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

func GetSetProfile(pfpki *types.Handler) http.Handler {
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
			body, err := ioutil.ReadAll(req.Body)
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

func SearchProfile(pfpki *types.Handler) http.Handler {
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

func GetProfileByID(pfpki *types.Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewProfileModel(pfpki)

		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog

		Error := types.Errors{Status: 0}

		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars := mux.Vars(req)
			Information, err = o.GetByID(vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
				break
			}

		case "PATCH":
			Information.Status = http.StatusOK
			body, err := ioutil.ReadAll(req.Body)
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

func GetSetCert(pfpki *types.Handler) http.Handler {
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
			body, err := ioutil.ReadAll(req.Body)
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

func SearchCert(pfpki *types.Handler) http.Handler {
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

func GetCertByID(pfpki *types.Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCertModel(pfpki)
		var Information types.Info
		var err error

		Error := types.Errors{Status: 0}

		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars := mux.Vars(req)
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

func DownloadCert(pfpki *types.Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCertModel(pfpki)
		var Information types.Info
		var err error

		Error := types.Errors{Status: 0}

		vars := mux.Vars(req)
		if len(regexp.MustCompile(`^[0-9]+$`).FindStringIndex(vars["id"])) > 0 {
			delete(vars, "cn")
		} else {
			vars["cn"] = vars["id"]
			delete(vars, "id")
		}
		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars := mux.Vars(req)
			Information, err = o.Download(vars)
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

func EmailCert(pfpki *types.Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCertModel(pfpki)
		var Information types.Info
		var err error

		Error := types.Errors{Status: 0}

		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars := mux.Vars(req)
			Information, err = o.Download(vars)
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

func RevokeCert(pfpki *types.Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCertModel(pfpki)
		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog = nil

		Error := types.Errors{Status: 0}

		vars := mux.Vars(req)
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

func GetRevoked(pfpki *types.Handler) http.Handler {
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

func SearchRevoked(pfpki *types.Handler) http.Handler {
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

func GetRevokedByID(pfpki *types.Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewRevokedCertModel(pfpki)
		var Information types.Info
		var err error

		Error := types.Errors{Status: 0}
		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars := mux.Vars(req)
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

func CheckRenewal(pfpki *types.Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCertModel(pfpki)
		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog = nil

		Error := types.Errors{Status: 0}
		switch req.Method {
		case "GET":
			Information.Status = http.StatusOK
			vars := mux.Vars(req)
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

func SignCSR(pfpki *types.Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		o := models.NewCsrModel(pfpki)

		var Information types.Info
		var err error
		var auditLog *admin_api_audit_log.AdminApiAuditLog

		Error := types.Errors{Status: 0}
		vars := mux.Vars(req)
		switch req.Method {

		case "POST":
			Information.Status = http.StatusCreated
			body, err := ioutil.ReadAll(req.Body)
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

func ManageOcsp(pfpki *types.Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		log.LoggerWContext(*pfpki.Ctx).Info(fmt.Sprintf("Got %s request from %s", req.Method, req.RemoteAddr))
		if req.Header.Get("Content-Type") != "application/ocsp-request" {
			log.LoggerWContext(*pfpki.Ctx).Info("Strict mode requires correct Content-Type header")
			res.WriteHeader(http.StatusBadRequest)
			return
		}

		b := new(bytes.Buffer)
		switch req.Method {
		case "POST":
			b.ReadFrom(req.Body)
		case "GET":
			log.LoggerWContext(*pfpki.Ctx).Info(req.URL.Path)
			gd, err := base64.StdEncoding.DecodeString(req.URL.Path[1:])
			if err != nil {
				log.LoggerWContext(*pfpki.Ctx).Info(err.Error())
				res.WriteHeader(http.StatusBadRequest)
				return
			}
			r := bytes.NewReader(gd)
			b.ReadFrom(r)
		default:
			log.LoggerWContext(*pfpki.Ctx).Info("Unsupported request method")
			res.WriteHeader(http.StatusBadRequest)
			return
		}
		oscp := Responder(pfpki)
		// parse request, verify, create response
		res.Header().Set("Content-Type", "application/ocsp-response")
		resp, err := oscp.Verify(b.Bytes())
		if err != nil {
			log.LoggerWContext(*pfpki.Ctx).Info(err.Error())
			// technically we should return an ocsp error response. but this is probably fine
			res.WriteHeader(http.StatusBadRequest)
			return
		}
		log.LoggerWContext(*pfpki.Ctx).Info("Writing response")
		res.Write(resp)
	})
}

func ManageSCEP(pfpki *types.Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		log.LoggerWContext(*pfpki.Ctx).Info(fmt.Sprintf("Got %s request from %s", req.Method, req.RemoteAddr))
		scep.ScepHandler(pfpki, res, req)
	})
}

// I decided on these defaults based on what I was using
func Responder(pfpki *types.Handler) *ocspresponder.OCSPResponder {
	return &ocspresponder.OCSPResponder{
		RespKeyFile: "responder.key",
		Strict:      false,
		CaCert:      nil,
		RespCert:    nil,
		NonceList:   nil,
		Handler:     pfpki,
	}
}
