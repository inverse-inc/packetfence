package main

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/davecgh/go-spew/spew"
	"github.com/gorilla/mux"
)

// Node struct
type Node struct {
	Mac string `json:"MAC"`
	Ip  string `json:"IP"`
}

// Node struct
type Stats struct {
	EthernetName string `json:"Interface"`
	Net          string `json:"Network"`
	Free         int    `json:"Free"`
}

type ApiReq struct {
	Req          string
	NetInterface string
	NetWork      string
	Mac          string
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
	http.Error(res, "Not found", http.StatusInternalServerError)
	return
}

func handleStats(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if _, ok := ControlIn[vars["int"]]; ok {
		Request := ApiReq{Req: "stats", NetInterface: vars["int"], NetWork: ""}
		ControlIn[vars["int"]] <- Request

		stat := <-ControlOut[vars["int"]]

		outgoingJSON, error := json.Marshal(stat)

		if error != nil {
			http.Error(res, error.Error(), http.StatusInternalServerError)
			return
		}

		fmt.Fprint(res, string(outgoingJSON))
		return
	} else {
		http.Error(res, "Not found", http.StatusInternalServerError)
		return
	}
}

func handleParking(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	InterFaceName, NetWork := InterfaceScopeFromMac(vars["mac"])
	if _, ok := ControlIn[InterFaceName]; ok {
		Request := ApiReq{Req: "parking", NetInterface: InterFaceName, NetWork: NetWork, Mac: vars["mac"]}
		ControlIn[InterFaceName] <- Request
		stat := <-ControlOut[InterFaceName]
		spew.Dump(stat)
	}

	spew.Dump(InterFaceName)
	spew.Dump(NetWork)
}
