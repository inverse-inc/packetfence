package pfpki

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
	"github.com/inverse-inc/packetfence/go/log"
)

type (
	// Info struct
	Info struct {
		Status      int         `json:"status"`
		Password    string      `json:"password"`
		Error       string      `json:"error"`
		ContentType string      `json:"contentType"`
		Raw         []byte      `json:"raw"`
		Entries     interface{} `json:"items"`
		NextCursor  int         `json:"nextCursor"`
		PrevCursor  int         `json:"prevCursor"`
		TotalCount  int         `json:"total_count"`
	}

	// Create interface
	Create interface {
		new() error
		get() error
		revoke() error
	}

	// Error struct
	Error struct {
		Field   string `json:"field"`
		Message string `json:"message"`
	}
	// Error struct
	Errors struct {
		Errors  []Error `json:"errors"`
		Message string  `json:"message"`
		Status  int     `json:"status"`
	}
)

func searchCA(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o CA
		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}

		switch req.Method {
		case "POST":
			var vars Vars
			if err := vars.DecodeBodyJson(req); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			Information, err = o.search(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
			}
			Information.Status = http.StatusOK
		default:
			err = errors.New("Method " + req.Method + " not supported")
			Information.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func getSetCA(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		var o CA
		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}

		switch req.Method {
		case "GET":
			vars, err := DecodeUrlQuery(req)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			Information, err = o.paginated(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			Information.Status = http.StatusOK

		case "POST":
			body, err := ioutil.ReadAll(req.Body)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			if err = json.Unmarshal(body, &o); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			if Information, err = o.new(pfpki); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusUnprocessableEntity
			}
			Information.Status = http.StatusCreated

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func getCAByID(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		var o CA
		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}

		switch req.Method {
		case "GET":
			vars := mux.Vars(req)
			Information, err = o.getById(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
			}
			Information.Status = http.StatusOK

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func fixCA(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		var o CA
		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}

		Information, err = o.fix(pfpki)
		if err != nil {
			Error.Message = err.Error()
			Error.Status = http.StatusNotFound
		}
		Information.Status = http.StatusOK
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func getSetProfile(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o Profile
		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}

		switch req.Method {
		case "GET":
			vars, err := DecodeUrlQuery(req)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			Information, err = o.paginated(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			Information.Status = http.StatusOK

		case "POST":
			body, err := ioutil.ReadAll(req.Body)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			if err = json.Unmarshal(body, &o); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			if Information, err = o.new(pfpki); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusUnprocessableEntity
			}
			Information.Status = http.StatusCreated

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func searchProfile(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o Profile
		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}

		switch req.Method {
		case "POST":
			var vars Vars
			if err := vars.DecodeBodyJson(req); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			Information, err = o.search(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
			}
			Information.Status = http.StatusOK

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func getProfileByID(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o Profile

		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}

		switch req.Method {
		case "GET":
			vars := mux.Vars(req)
			Information, err = o.getById(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
			}
			Information.Status = http.StatusOK

		case "PATCH":
			body, err := ioutil.ReadAll(req.Body)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			if err = json.Unmarshal(body, &o); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			if Information, err = o.update(pfpki); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusUnprocessableEntity
			}
			Information.Status = http.StatusOK

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func getSetCert(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o Cert

		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}

		switch req.Method {
		case "GET":
			vars, err := DecodeUrlQuery(req)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			Information, err = o.paginated(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			Information.Status = http.StatusOK

		case "POST":
			body, err := ioutil.ReadAll(req.Body)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			if err = json.Unmarshal(body, &o); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			if Information, err = o.new(pfpki); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusUnprocessableEntity
			}
			Information.Status = http.StatusCreated

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func searchCert(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o Cert
		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}

		switch req.Method {
		case "POST":
			var vars Vars
			if err := vars.DecodeBodyJson(req); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			Information, err = o.search(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
			}
			Information.Status = http.StatusOK

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func getCertByID(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o Cert
		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}

		switch req.Method {
		case "GET":
			vars := mux.Vars(req)
			Information, err = o.getById(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
			}
			Information.Status = http.StatusOK

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func downloadCert(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o Cert
		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}

		vars := mux.Vars(req)
		if len(regexp.MustCompile(`^[0-9]+$`).FindStringIndex(vars["id"])) > 0 {
			delete(vars, "cn")
		} else {
			vars["cn"] = vars["id"]
			delete(vars, "id")
		}
		switch req.Method {
		case "GET":
			vars := mux.Vars(req)
			Information, err = o.download(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
			}
			Information.Status = http.StatusOK

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func emailCert(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o Cert
		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}

		switch req.Method {
		case "GET":
			vars := mux.Vars(req)
			Information, err = o.download(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
			}
			Information.Status = http.StatusOK

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func revokeCert(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o Cert
		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}

		vars := mux.Vars(req)
		if len(regexp.MustCompile(`^[0-9]+$`).FindStringIndex(vars["id"])) > 0 {
			delete(vars, "cn")
		} else {
			vars["cn"] = vars["id"]
			delete(vars, "id")
		}
		switch req.Method {
		case "DELETE":
			Information, err = o.revoke(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusUnprocessableEntity
			}
			Information.Status = http.StatusOK

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func getRevoked(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o RevokedCert
		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}
		switch req.Method {
		case "GET":
			vars, err := DecodeUrlQuery(req)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			Information, err = o.paginated(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			Information.Status = http.StatusOK

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func searchRevoked(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o RevokedCert
		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}
		switch req.Method {
		case "POST":
			var vars Vars
			if err := vars.DecodeBodyJson(req); err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusInternalServerError
			}
			Information, err = o.search(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
			}
			Information.Status = http.StatusOK

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func getRevokedByID(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o RevokedCert
		var Information Info
		var err error
		var Error Errors

		Error = Errors{Status: 0}
		switch req.Method {
		case "GET":
			vars := mux.Vars(req)
			Information, err = o.getById(pfpki, vars)
			if err != nil {
				Error.Message = err.Error()
				Error.Status = http.StatusNotFound
			}
			Information.Status = http.StatusOK

		default:
			err = errors.New("Method " + req.Method + " not supported")
			Error.Message = err.Error()
			Error.Status = http.StatusMethodNotAllowed
		}
		manageAnswer(Information, Error, pfpki, res, req)
	})
}

func manageAnswer(Information Info, Error Errors, pfpki *Handler, res http.ResponseWriter, req *http.Request) {
	var err error

	if Error.Status != 0 {
		res.Header().Set("Content-Type", "application/json; charset=UTF-8")
		res.WriteHeader(http.StatusOK)
		log.LoggerWContext(pfpki.Ctx).Error(Information.Error)
		if err := json.NewEncoder(res).Encode(&Error); err != nil {
			fmt.Println(err)
		}
		return
	}
	if err != nil {
		log.LoggerWContext(pfpki.Ctx).Info(err.Error())
		if Information.Status >= 400 {
			Information.Error = http.StatusText(Information.Status)
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

func manageOcsp(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		log.LoggerWContext(pfpki.Ctx).Info(fmt.Sprintf("Got %s request from %s", req.Method, req.RemoteAddr))
		if req.Header.Get("Content-Type") != "application/ocsp-request" {
			log.LoggerWContext(pfpki.Ctx).Info("Strict mode requires correct Content-Type header")
			res.WriteHeader(http.StatusBadRequest)
			return
		}

		b := new(bytes.Buffer)
		switch req.Method {
		case "POST":
			b.ReadFrom(req.Body)
		case "GET":
			log.LoggerWContext(pfpki.Ctx).Info(req.URL.Path)
			gd, err := base64.StdEncoding.DecodeString(req.URL.Path[1:])
			if err != nil {
				log.LoggerWContext(pfpki.Ctx).Info(err.Error())
				res.WriteHeader(http.StatusBadRequest)
				return
			}
			r := bytes.NewReader(gd)
			b.ReadFrom(r)
		default:
			log.LoggerWContext(pfpki.Ctx).Info("Unsupported request method")
			res.WriteHeader(http.StatusBadRequest)
			return
		}
		oscp := Responder(pfpki)
		// parse request, verify, create response
		res.Header().Set("Content-Type", "application/ocsp-response")
		resp, err := oscp.verify(b.Bytes())
		if err != nil {
			log.LoggerWContext(pfpki.Ctx).Info(err.Error())
			// technically we should return an ocsp error response. but this is probably fine
			res.WriteHeader(http.StatusBadRequest)
			return
		}
		log.LoggerWContext(pfpki.Ctx).Info("Writing response")
		res.Write(resp)
	})
}
