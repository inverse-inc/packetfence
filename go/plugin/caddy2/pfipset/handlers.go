package pfipset

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"os/exec"

	"github.com/gorilla/mux"
	ipset "github.com/inverse-inc/go-ipset/v2"
	"github.com/inverse-inc/go-utils/log"
	"github.com/inverse-inc/go-utils/mac"
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
	IPSET.IPSEThandleLayer2(req.Context(), Ip, Mac, Network.String(), Type, RoleId)

	var result = map[string][]*Info{
		"result": {
			&Info{Mac: Mac.String(), Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func ipsetTest(name string, options ...ipset.EntryOption) error {
	conn := getConn()
	defer putConn(conn)
	return conn.Test(name, options...)
}

func (IPSET *pfIPSET) IPSEThandleLayer2(ctx context.Context, Ip net.IP, Mac mac.Mac, Network string, Type string, RoleId string) {
	logger := log.LoggerWContext(ctx)
	typeMap := make(map[string]string, len(IPSET.ListALL))
	for _, v := range IPSET.ListALL {
		name := v.Name.Get()
		typeName := v.TypeName.Get()
		typeMap[name] = typeName
		// Delete all entries with the new ip address
		if typeName == "hash:ip,port" {
			continue
		}

		r := ipsetTest(name, ipset.EntryIP(Ip))
		if r == nil {
			IPSET.jobs <- job{"Del", name, ipset.NewEntry(ipset.EntryIP(Ip))}
			logger.Info("Removed " + Ip.String() + " from " + name + " Mac: " + Mac.String())
		}
		// Delete all entries with old ip addresses
		entries := IPSET.mac2ip(ctx, Mac, &v)
		for _, e := range entries {
			IPSET.jobs <- job{"Del", name, e}
			logger.Info("Removed old ip " + e.IP.Get().String() + " from " + name + " Mac: " + Mac.String())
		}
	}
	var entry *ipset.Entry
	name := "pfsession_" + Type + "_" + Network
	if typeMap[name] == "bitmap:ip,mac" {
		entry = ipset.NewEntry(
			ipset.EntryIP(Ip),
			ipset.EntryEther(net.HardwareAddr(Mac[:])),
		)
	} else {
		entry = ipset.NewEntry(
			ipset.EntryIP(Ip),
		)
	}
	// Add to the new ipset session
	IPSET.jobs <- job{"Add", name, entry}
	logger.Info("Added " + Ip.String() + " " + Mac.String() + " to pfsession_" + Type + "_" + Network)
	if Type == "Reg" {
		// Add to the ip ipset session
		IPSET.jobs <- job{"Add", "PF-iL2_ID" + RoleId + "_" + Network, ipset.NewEntry(ipset.EntryIP(Ip))}
		logger.Info("Added " + Ip.String() + " to PF-iL2_ID" + RoleId + "_" + Network + " Mac: " + Mac.String())
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
	IPSET.IPSEThandleMarkIpL2(ctx, Ip, Network.String(), RoleId)

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

func (IPSET *pfIPSET) IPSEThandleMarkIpL2(ctx context.Context, Ip net.IP, Network string, RoleId string) {
	IPSET.jobs <- job{"Add", "PF-iL2_ID" + RoleId + "_" + Network, ipset.NewEntry(ipset.EntryIP(Ip))}
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
	IPSET.IPSEThandleMarkIpL3(ctx, Ip, Network.String(), RoleId)

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

func (IPSET *pfIPSET) IPSEThandleMarkIpL3(ctx context.Context, Ip net.IP, Network string, RoleId string) {
	IPSET.jobs <- job{"Add", "PF-iL3_ID" + RoleId + "_" + Network, ipset.NewEntry(ipset.EntryIP(Ip))}
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
	IPSET.IPSEThandleLayer3(ctx, Ip, Network.String(), Type, RoleId)

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

func (IPSET *pfIPSET) IPSEThandleLayer3(ctx context.Context, Ip net.IP, Network string, Type string, RoleId string) {
	logger := log.LoggerWContext(ctx)

	// Delete all entries with the new ip address
	for _, v := range IPSET.ListALL {
		if v.TypeName.Get() == "hash:ip,port" {
			continue
		}
		name := v.Name.Get()
		r := ipsetTest(name, ipset.EntryIP(Ip))
		if r == nil {
			IPSET.jobs <- job{"Del", name, ipset.NewEntry(ipset.EntryIP(Ip))}
			logger.Info("Removed " + Ip.String() + " from " + name)
		}
	}
	// Add to the new ipset session
	IPSET.jobs <- job{"Add", "pfsession_" + Type + "_" + Network, ipset.NewEntry(ipset.EntryIP(Ip))}
	logger.Info("Added " + Ip.String() + " to pfsession_" + Type + "_" + Network)
	if Type == "Reg" {
		// Add to the ip ipset session
		IPSET.jobs <- job{"Add", "PF-iL3_ID" + RoleId + "_" + Network, ipset.NewEntry(ipset.EntryIP(Ip))}
		logger.Info("Added " + Ip.String() + " to PF-iL3_ID" + RoleId + "_" + Network)
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
		Ips := IPSET.mac2ip(req.Context(), Mac, &v)
		name := v.Name.Get()
		for _, i := range Ips {
			IPSET.jobs <- job{"Del", name, i}
			ip := i.IP.Get()
			IPSET.DeleteConnectionBySrcIp(ip.String())
			logger.Info(fmt.Sprintf("Removed %s from %s", ip.String(), name))
		}
	}
	var result = map[string][]*Info{
		"result": {
			&Info{Mac: Mac.String(), Status: "ACK"},
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

	entry := ipset.NewEntry(ipset.EntryIP(Ip))
	for _, v := range IPSET.ListALL {
		if v.TypeName.Get() == "hash:ip,port" {
			continue
		}
		name := v.Name.Get()
		r := ipsetTest(name, ipset.EntryIP(Ip))
		if r == nil {
			IPSET.jobs <- job{"Del", name, entry}
			IPSET.DeleteConnectionBySrcIp(Ip.String())
			logger.Info(fmt.Sprintf("Removed %s from %s", Ip, name))
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

func (IPSET *pfIPSET) DeleteConnectionBySrcIp(ip string) {
	if conntrackBinary != "" {
		args := []string{"-D", "-s", ip}
		stdout := bytes.Buffer{}
		stderr := bytes.Buffer{}
		cmd := exec.Cmd{
			Path:   conntrackBinary,
			Args:   args,
			Stdout: &stdout,
			Stderr: &stderr,
		}

		_ = cmd.Run()
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

var conntrackBinary = ""

func init() {
	path, err := exec.LookPath("conntrack")
	if err == nil {
		conntrackBinary = path
	}
}
