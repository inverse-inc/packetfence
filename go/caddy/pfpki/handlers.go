package pfpki

import (
	"encoding/json"
	"errors"
	"io/ioutil"
	"net/http"
	"regexp"

	"github.com/gorilla/mux"
)

// Info struct
type Info struct {
	Status string `json:"status"`
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
			err = v.new(pfpki)
		}
		if matched, _ := regexp.MatchString(`/pki/getca/`, req.URL.Path); matched {
			err = v.get(pfpki, vars["cn"])
		}
	case Cert:

		if matched, _ := regexp.MatchString(`/pki/newcert`, req.URL.Path); matched {
			err = json.Unmarshal(body, &v)
			if err != nil {
				panic(err)
			}
			err = v.new(pfpki)
		}
		if matched, _ := regexp.MatchString(`/pki/getcert/`, req.URL.Path); matched {
			err = v.get(pfpki, vars["cn"])
		}
	case Profile:

		err = json.Unmarshal(body, &v)
		if err != nil {
			panic(err)
		}
		err = v.new(pfpki)
	default:

		err = errors.New("invalid type")
	}

	var status string

	if err != nil {
		status = err.Error()
	} else {
		status = "ACK"
	}

	var result = map[string][]*Info{
		"result": {
			&Info{Status: status},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}
