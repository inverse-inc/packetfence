package main

import (
	"encoding/json"
	"errors"
	"io/ioutil"
	"net/http"
)

// Info struct
type Info struct {
	Status string `json:"status"`
}

// Create interface
type Create interface {
	new() error
}

func newCA(res http.ResponseWriter, req *http.Request) {

	var o CA

	create(o, res, req)
}

func newCert(res http.ResponseWriter, req *http.Request) {

	var o Cert

	create(o, res, req)
}

func newProfile(res http.ResponseWriter, req *http.Request) {

	var o Profile

	create(o, res, req)
}

func create(object interface{}, res http.ResponseWriter, req *http.Request) {

	body, err := ioutil.ReadAll(req.Body)
	if err != nil {
		panic(err)
	}

	switch v := object.(type) {
	case CA:
		err = json.Unmarshal(body, &v)
		if err != nil {
			panic(err)
		}
		err = v.new()
	case Cert:
		err = json.Unmarshal(body, &v)
		if err != nil {
			panic(err)
		}
		err = v.new()
	case Profile:
		err = json.Unmarshal(body, &v)
		if err != nil {
			panic(err)
		}
		err = v.new()
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
