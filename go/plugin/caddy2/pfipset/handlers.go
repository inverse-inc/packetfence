package pfipset

import (
	"encoding/json"
	"io/ioutil"
	"net"
	"net/http"

	"github.com/gorilla/mux"
	ipset "github.com/inverse-inc/go-ipset/v2"
	"github.com/inverse-inc/go-utils/sharedutils"
)

type Info struct {
	Status string `json:"status"`
	Mac    string `json:"mac"`
	Ip     string `json:"ip"`
}

type PostOptions struct {
	Network string `json:"network,omitempty"`
	RoleId  string `json:"role_id,omitempty"`
	Ip      string `json:"ip,omitempty"`
	Port    string `json:"port,omitempty"`
	Mac     string `json:"mac,omitempty"`
	Type    string `json:"type,omitempty"`
}

func handleAddIp(res http.ResponseWriter, req *http.Request) {
	IPSET := pfIPSETFromContext(req.Context())

	updateClusterRequest(req.Context(), req)

	body, err := ioutil.ReadAll(req.Body)
	if err != nil {
		panic(err)
	}
	var o PostOptions
	err = json.Unmarshal(body, &o)
	if err != nil {
		panic(err)
	}
	Ip := net.ParseIP(o.Ip)
	if Ip == nil {
		handleError(res, http.StatusBadRequest)
		return
	}
	setName := mux.Vars(req)["set_name"]

	IPSET.jobs <- job{"Add", setName, ipset.NewEntry(ipset.EntryIP(Ip))}
	var result = map[string][]*Info{
		"result": {
			&Info{Ip: Ip.String(), Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}

}

func handleRemoveIp(res http.ResponseWriter, req *http.Request) {
	IPSET := pfIPSETFromContext(req.Context())

	updateClusterRequest(req.Context(), req)

	body, err := ioutil.ReadAll(req.Body)
	if err != nil {
		panic(err)
	}
	var o PostOptions
	err = json.Unmarshal(body, &o)
	if err != nil {
		panic(err)
	}
	Ip := net.ParseIP(o.Ip)
	if Ip == nil {
		handleError(res, http.StatusBadRequest)
		return
	}
	setName := mux.Vars(req)["set_name"]

	IPSET.jobs <- job{"Del", setName, ipset.NewEntry(ipset.EntryIP(Ip))}
	var result = map[string][]*Info{
		"result": {
			&Info{Ip: Ip.String(), Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}

}

func handlePassthrough(res http.ResponseWriter, req *http.Request) {
	IPSET := pfIPSETFromContext(req.Context())

	updateClusterRequest(req.Context(), req)

	body, err := ioutil.ReadAll(req.Body)
	if err != nil {
		panic(err)
	}
	var o PostOptions
	err = json.Unmarshal(body, &o)
	if err != nil {
		panic(err)
	}
	Ip := net.ParseIP(o.Ip)
	if Ip == nil {
		handleError(res, http.StatusBadRequest)
		return
	}

	Port, proto, valid_port := validatePort(o.Port)
	if !valid_port {
		handleError(res, http.StatusBadRequest)
		return
	}

	IPSET.jobs <- job{
		"Add",
		"pfsession_passthrough",
		ipset.NewEntry(
			ipset.EntryIP(Ip),
			ipset.EntryPort(Port),
			ipset.EntryProto(proto),
		),
	}

	var result = map[string][]*Info{
		"result": {
			&Info{Ip: Ip.String(), Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}

}

func handleIsolationPassthrough(res http.ResponseWriter, req *http.Request) {
	IPSET := pfIPSETFromContext(req.Context())

	Local := req.URL.Query().Get("local")
	if Local == "0" {
		newReq, err := sharedutils.CopyHttpRequest(req)
		sharedutils.CheckError(err)
		updateClusterRequest(req.Context(), newReq)
	}

	body, err := ioutil.ReadAll(req.Body)
	if err != nil {
		panic(err)
	}
	var o PostOptions
	err = json.Unmarshal(body, &o)
	if err != nil {
		panic(err)
	}
	Ip := net.ParseIP(o.Ip)
	if Ip == nil {
		handleError(res, http.StatusBadRequest)
		return
	}

	Port, proto, valid_port := validatePort(o.Port)
	if !valid_port {
		handleError(res, http.StatusBadRequest)
		return
	}

	IPSET.jobs <- job{
		"Add",
		"pfsession_isol_passthrough",
		ipset.NewEntry(
			ipset.EntryIP(Ip),
			ipset.EntryPort(Port),
			ipset.EntryProto(proto),
		),
	}
	var result = map[string][]*Info{
		"result": {
			&Info{Ip: Ip.String(), Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}

}

func handleError(res http.ResponseWriter, code int) {
	var result = map[string][]*Info{
		"result": {
			&Info{Status: "NAK"},
		},
	}
	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(code)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}
