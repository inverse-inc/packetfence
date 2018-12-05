package pfipset

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"

	"github.com/diegoguarnieri/go-conntrack/conntrack"
	ipset "github.com/fdurand/go-ipset"
	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/log"
	"github.com/inverse-inc/packetfence/go/sharedutils"
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

	IPSET.jobs <- job{"Add", setName, Ip.String()}
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

	IPSET.jobs <- job{"Del", setName, Ip.String()}
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
	Port, valid_port := validatePort(o.Port)
	if !valid_port {
		handleError(res, http.StatusBadRequest)
		return
	}

	IPSET.jobs <- job{"Add", "pfsession_passthrough", Ip.String() + "," + Port}
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
	Port, valid_port := validatePort(o.Port)
	if !valid_port {
		handleError(res, http.StatusBadRequest)
		return
	}

	IPSET.jobs <- job{"Add", "pfsession_isol_passthrough", Ip.String() + "," + Port}
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

func handleLayer2(res http.ResponseWriter, req *http.Request) {
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
	Type, valid_type := validateType(o.Type)
	if !valid_type {
		handleError(res, http.StatusBadRequest)
		return
	}
	Network := net.ParseIP(o.Network)
	if Network == nil {
		handleError(res, http.StatusBadRequest)
		return
	}
	RoleId, valid_roleid := validateRoleId(o.RoleId)
	if !valid_roleid {
		handleError(res, http.StatusBadRequest)
		return
	}
	Mac, valid_mac := validateMac(o.Mac)
	if !valid_mac {
		handleError(res, http.StatusBadRequest)
		return
	}

	// Update locally
	IPSET.IPSEThandleLayer2(req.Context(), Ip.String(), Mac, Network.String(), Type, RoleId)

	var result = map[string][]*Info{
		"result": {
			&Info{Mac: Mac, Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func (IPSET *pfIPSET) IPSEThandleLayer2(ctx context.Context, Ip string, Mac string, Network string, Type string, RoleId string) {
	logger := log.LoggerWContext(ctx)

	for _, v := range IPSET.ListALL {
		// Delete all entries with the new ip address
		if v.Type == "hash:ip,port" {
			continue
		}
		r := ipset.Test(v.Name, Ip)
		if r == nil {
			IPSET.jobs <- job{"Del", v.Name, Ip}
			logger.Info("Removed " + Ip + " from " + v.Name)
		}
		// Delete all entries with old ip addresses
		Ips := IPSET.mac2ip(ctx, Mac, v)
		for _, i := range Ips {
			IPSET.jobs <- job{"Del", v.Name, i}
			logger.Info("Removed " + i + " from " + v.Name)
		}
	}
	// Add to the new ipset session
	IPSET.jobs <- job{"Add", "pfsession_" + Type + "_" + Network, Ip + "," + Mac}
	logger.Info("Added " + Ip + " " + Mac + " to pfsession_" + Type + "_" + Network)
	if Type == "Reg" {
		// Add to the ip ipset session
		IPSET.jobs <- job{"Add", "PF-iL2_ID" + RoleId + "_" + Network, Ip}
		logger.Info("Added " + Ip + " to PF-iL2_ID" + RoleId + "_" + Network)
	}
}

func handleMarkIpL2(res http.ResponseWriter, req *http.Request) {
	ctx := req.Context()

	updateClusterRequest(req.Context(), req)

	IPSET := pfIPSETFromContext(req.Context())

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
	Network := net.ParseIP(o.Network)
	if Network == nil {
		handleError(res, http.StatusBadRequest)
		return
	}
	RoleId, valid_roleid := validateRoleId(o.RoleId)
	if !valid_roleid {
		handleError(res, http.StatusBadRequest)
		return
	}

	// Update locally
	IPSET.IPSEThandleMarkIpL2(ctx, Ip.String(), Network.String(), RoleId)

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

func (IPSET *pfIPSET) IPSEThandleMarkIpL2(ctx context.Context, Ip string, Network string, RoleId string) {
	IPSET.jobs <- job{"Add", "PF-iL2_ID" + RoleId + "_" + Network, Ip}
}

func handleMarkIpL3(res http.ResponseWriter, req *http.Request) {
	ctx := req.Context()

	updateClusterRequest(req.Context(), req)

	IPSET := pfIPSETFromContext(req.Context())

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
	Network := net.ParseIP(o.Network)
	if Network == nil {
		handleError(res, http.StatusBadRequest)
		return
	}
	RoleId, valid_roleid := validateRoleId(o.RoleId)
	if !valid_roleid {
		handleError(res, http.StatusBadRequest)
		return
	}

	// Update locally
	IPSET.IPSEThandleMarkIpL3(ctx, Ip.String(), Network.String(), RoleId)

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

func (IPSET *pfIPSET) IPSEThandleMarkIpL3(ctx context.Context, Ip string, Network string, RoleId string) {
	IPSET.jobs <- job{"Add", "PF-iL3_ID" + RoleId + "_" + Network, Ip}
}

func handleLayer3(res http.ResponseWriter, req *http.Request) {
	ctx := req.Context()

	updateClusterRequest(req.Context(), req)

	IPSET := pfIPSETFromContext(req.Context())

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
	Type, valid_type := validateType(o.Type)
	if !valid_type {
		handleError(res, http.StatusBadRequest)
		return
	}
	Network := net.ParseIP(o.Network)
	if Network == nil {
		handleError(res, http.StatusBadRequest)
		return
	}
	RoleId, valid_roleid := validateRoleId(o.RoleId)
	if !valid_roleid {
		handleError(res, http.StatusBadRequest)
		return
	}

	// Update locally
	IPSET.IPSEThandleLayer3(ctx, Ip.String(), Network.String(), Type, RoleId)

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

func (IPSET *pfIPSET) IPSEThandleLayer3(ctx context.Context, Ip string, Network string, Type string, RoleId string) {
	logger := log.LoggerWContext(ctx)

	// Delete all entries with the new ip address
	for _, v := range IPSET.ListALL {
		if v.Type == "hash:ip,port" {
			continue
		}
		r := ipset.Test(v.Name, Ip)
		if r == nil {
			IPSET.jobs <- job{"Del", v.Name, Ip}
			logger.Info("Removed " + Ip + " from " + v.Name)
		}
	}
	// Add to the new ipset session
	IPSET.jobs <- job{"Add", "pfsession_" + Type + "_" + Network, Ip}
	logger.Info("Added " + Ip + " to pfsession_" + Type + "_" + Network)
	if Type == "Reg" {
		// Add to the ip ipset session
		IPSET.jobs <- job{"Add", "PF-iL3_ID" + RoleId + "_" + Network, Ip}
		logger.Info("Added " + Ip + " to PF-iL3_ID" + RoleId + "_" + Network)
	}
}

func (IPSET *pfIPSET) handleUnmarkMac(res http.ResponseWriter, req *http.Request) {
	ctx := req.Context()
	logger := log.LoggerWContext(ctx)

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
	Mac, valid_mac := validateMac(o.Mac)
	if !valid_mac {
		handleError(res, http.StatusBadRequest)
		return
	}

	for _, v := range IPSET.ListALL {
		Ips := IPSET.mac2ip(req.Context(), Mac, v)
		for _, i := range Ips {
			IPSET.jobs <- job{"Del", v.Name, i}
			conn, _ := conntrack.New()
			conn.DeleteConnectionBySrcIp(i)
			logger.Info(fmt.Sprintf("Removed %s from %s", i, v.Name))
		}
	}
	var result = map[string][]*Info{
		"result": {
			&Info{Mac: Mac, Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func (IPSET *pfIPSET) handleUnmarkIp(res http.ResponseWriter, req *http.Request) {
	ctx := req.Context()
	logger := log.LoggerWContext(ctx)

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

	for _, v := range IPSET.ListALL {
		if v.Type == "hash:ip,port" {
			continue
		}
		r := ipset.Test(v.Name, Ip.String())
		if r == nil {
			IPSET.jobs <- job{"Del", v.Name, Ip.String()}
			conn, _ := conntrack.New()
			conn.DeleteConnectionBySrcIp(Ip.String())
			logger.Info(fmt.Sprintf("Removed %s from %s", Ip, v.Name))
		}
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
