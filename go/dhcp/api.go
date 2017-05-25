package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"github.com/gorilla/mux"
)

// Node struct
type Node struct {
	Mac string `json:"MAC"`
	Ip  string `json:"IP"`
}

func handleIP2Mac(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if index, found := GlobalIpCache.Get(vars["ip"]); found {
		var node = map[string]*Node{
			"result": &Node{Mac: index.(string), Ip: vars["ip"]},
		}

		outgoingJSON, error := json.Marshal(node)

		if error != nil {
			http.Error(res, error.Error(), http.StatusInternalServerError)
			return
		}

		fmt.Fprint(res, string(outgoingJSON))
		return
	}
	log.Println("Not found")
	http.Error(res, "Not found", http.StatusInternalServerError)
	return
}

func handleMac2Ip(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if index, found := GlobalMacCache.Get(vars["mac"]); found {
		var node = map[string]*Node{
			"result": &Node{Mac: vars["mac"], Ip: index.(string)},
		}

		outgoingJSON, error := json.Marshal(node)

		if error != nil {
			http.Error(res, error.Error(), http.StatusInternalServerError)
			return
		}

		fmt.Fprint(res, string(outgoingJSON))
		return
	}
	log.Println("Not found")
	http.Error(res, "Not found", http.StatusInternalServerError)
	return
}
