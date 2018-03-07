package main

import (
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net"
	"net/http"

	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/sharedutils"
	dhcp "github.com/krolaw/dhcp4"
)

// Node struct
type Node struct {
	Mac string `json:"mac"`
	IP  string `json:"ip"`
}

// Stats struct
type Stats struct {
	EthernetName string            `json:"interface"`
	Net          string            `json:"network"`
	Free         int               `json:"free"`
	Category     string            `json:"category"`
	Options      map[string]string `json:"options"`
	Members      map[string]string `json:"members"`
	Status       string            `json:"status"`
}

type ApiReq struct {
	Req          string
	NetInterface string
	NetWork      string
	Mac          string
	Role         string
}

type Options struct {
	Option dhcp.OptionCode `json:"option"`
	Value  string          `json:"value"`
	Type   string          `json:"type"`
}

type Info struct {
	Status  string `json:"status"`
	Mac     string `json:"mac,omitempty"`
	Network string `json:"network,omitempty"`
}

func handleIP2Mac(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if index, found := GlobalIpCache.Get(vars["ip"]); found {
		var node = map[string]*Node{
			"result": &Node{Mac: index.(string), IP: vars["ip"]},
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
			"result": &Node{Mac: vars["mac"], IP: index.(string)},
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
	}
	http.Error(res, "Not found", http.StatusInternalServerError)
	return
}

func handleInitiaLease(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if _, ok := ControlIn[vars["int"]]; ok {
		Request := ApiReq{Req: "initialease", NetInterface: vars["int"], NetWork: ""}
		ControlIn[vars["int"]] <- Request

		stat := <-ControlOut[vars["int"]]

		outgoingJSON, error := json.Marshal(stat)

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

func handleDebug(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)

	if _, ok := ControlIn[vars["int"]]; ok {
		Request := ApiReq{Req: "debug", NetInterface: vars["int"], Role: vars["role"]}
		ControlIn[vars["int"]] <- Request

		stat := <-ControlOut[vars["int"]]

		outgoingJSON, error := json.Marshal(stat)

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

func handleReleaseIP(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	_ = InterfaceScopeFromMac(vars["mac"])

	var result = map[string][]*Info{
		"result": {
			&Info{Mac: vars["mac"], Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func handleOverrideOptions(res http.ResponseWriter, req *http.Request) {

	vars := mux.Vars(req)

	body, err := ioutil.ReadAll(io.LimitReader(req.Body, 1048576))
	if err != nil {
		panic(err)
	}
	if err := req.Body.Close(); err != nil {
		panic(err)
	}

	// Insert information in etcd
	_ = etcdInsert(vars["mac"], sharedutils.ConvertToString(body))

	var result = map[string][]*Info{
		"result": {
			&Info{Mac: vars["mac"], Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func handleOverrideNetworkOptions(res http.ResponseWriter, req *http.Request) {

	vars := mux.Vars(req)

	body, err := ioutil.ReadAll(io.LimitReader(req.Body, 1048576))
	if err != nil {
		panic(err)
	}
	if err := req.Body.Close(); err != nil {
		panic(err)
	}

	// Insert information in etcd
	_ = etcdInsert(vars["network"], sharedutils.ConvertToString(body))

	var result = map[string][]*Info{
		"result": {
			&Info{Network: vars["network"], Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func handleRemoveOptions(res http.ResponseWriter, req *http.Request) {

	vars := mux.Vars(req)

	var result = map[string][]*Info{
		"result": {
			&Info{Mac: vars["mac"], Status: "ACK"},
		},
	}

	err := etcdDel(vars["mac"])
	if !err {
		result = map[string][]*Info{
			"result": {
				&Info{Mac: vars["mac"], Status: "NAK"},
			},
		}
	}
	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func handleRemoveNetworkOptions(res http.ResponseWriter, req *http.Request) {

	vars := mux.Vars(req)

	var result = map[string][]*Info{
		"result": {
			&Info{Network: vars["network"], Status: "ACK"},
		},
	}

	err := etcdDel(vars["network"])
	if !err {
		result = map[string][]*Info{
			"result": {
				&Info{Network: vars["network"], Status: "NAK"},
			},
		}
	}
	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func decodeOptions(b string) (map[dhcp.OptionCode][]byte, bool) {
	var options []Options
	_, value := etcdGet(b)
	decodedValue := sharedutils.ConvertToByte(value)
	var dhcpOptions = make(map[dhcp.OptionCode][]byte)
	if err := json.Unmarshal(decodedValue, &options); err != nil {
		return dhcpOptions, false
	}
	for _, option := range options {
		var Value interface{}
		switch option.Type {
		case "ipaddr":
			Value = net.ParseIP(option.Value)
			dhcpOptions[option.Option] = Value.(net.IP).To4()
		case "string":
			Value = option.Value
			dhcpOptions[option.Option] = []byte(Value.(string))
		case "int":
			Value = option.Value
			dhcpOptions[option.Option] = []byte(Value.(string))
		}
	}
	return dhcpOptions, true
}
