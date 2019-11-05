package pfpki

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"regexp"

	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/log"
)

// Info struct
type Info struct {
	Status   string `json:"status"`
	Password string `json:"password"`
	Error    string `json:"error"`
}

// Create interface
type Create interface {
	new() error
	get() error
}

func manageCA(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o CA

		manage(o, pfpki, res, req)
	})
}

func manageCert(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o Cert

		manage(o, pfpki, res, req)
	})
}

func manageProfile(pfpki *Handler) http.Handler {
	return http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {

		var o Profile

		manage(o, pfpki, res, req)
	})
}

func manage(object interface{}, pfpki *Handler, res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	body, err := ioutil.ReadAll(req.Body)
	var Information Info
	if err != nil {
		panic(err)
	}

	switch v := object.(type) {
	case CA:

		if matched, _ := regexp.MatchString(`/pki/newca`, req.URL.Path); matched {
			err = json.Unmarshal(body, &v)
			if err != nil {
				panic(err)
			}
			Information, err = v.new(pfpki)
		}
		if matched, _ := regexp.MatchString(`/pki/getca/`, req.URL.Path); matched {
			Information, err = v.get(pfpki, vars["cn"])
		}
	case Cert:

		if matched, _ := regexp.MatchString(`/pki/newcert`, req.URL.Path); matched {
			err = json.Unmarshal(body, &v)
			if err != nil {
				panic(err)
			}
			Information, err = v.new(pfpki)
		}
		if matched, _ := regexp.MatchString(`/pki/getcert/`, req.URL.Path); matched {
			Information, err = v.get(pfpki, vars["cn"])
		}
	case Profile:

		err = json.Unmarshal(body, &v)
		if err != nil {
			panic(err)
		}
		Information, err = v.new(pfpki)
	default:

		err = errors.New("invalid type")
	}

	if err != nil {
		Information.Error = err.Error()
	} else {
		Information.Status = "ACK"
	}

	var result = map[string][]*Info{
		"result": {
			&Information,
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
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
