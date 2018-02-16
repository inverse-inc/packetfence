package pfipset

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/diegoguarnieri/go-conntrack/conntrack"
	ipset "github.com/digineo/go-ipset"
	"github.com/gorilla/mux"
	"github.com/inverse-inc/packetfence/go/log"
)

type Info struct {
	Status string `json:"status"`
	Mac    string `json:"MAC"`
	IP     string `json:"IP"`
}

func handlePassthrough(res http.ResponseWriter, req *http.Request) {
	IPSET := pfIPSETFromContext(req.Context())
	vars := mux.Vars(req)
	IP := vars["ip"]
	Port := vars["port"]
	Local := req.URL.Query().Get("local")

	IPSET.jobs <- job{"Add", "pfsession_passthrough", IP + "," + Port}
	if Local == "0" {
		updateClusterPassthrough(req.Context(), IP, Port)
	}
	var result = map[string][]*Info{
		"result": {
			&Info{IP: IP, Status: "ACK"},
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
	vars := mux.Vars(req)
	IP := vars["ip"]
	Port := vars["port"]
	Local := req.URL.Query().Get("local")

	IPSET.jobs <- job{"Add", "pfsession_isol_passthrough", IP + "," + Port}
	if Local == "0" {
		updateClusterPassthroughIsol(req.Context(), IP, Port)
	}
	var result = map[string][]*Info{
		"result": {
			&Info{IP: IP, Status: "ACK"},
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
	vars := mux.Vars(req)
	IP := vars["ip"]
	Mac := vars["mac"]
	Network := vars["network"]
	Type := vars["type"]
	Catid := vars["category_id"]
	Local := req.URL.Query().Get("local")

	// Update locally
	IPSET.IPSEThandleLayer2(req.Context(), IP, Mac, Network, Type, Catid)

	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterL2(req.Context(), IP, Mac, Network, Type, Catid)
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

func (IPSET *pfIPSET) IPSEThandleLayer2(ctx context.Context, IP string, Mac string, Network string, Type string, Catid string) {
	logger := log.LoggerWContext(ctx)

	for _, v := range IPSET.ListALL {
		// Delete all entries with the new ip address
		r := ipset.Test(v.Name, IP)
		if r == nil {
			IPSET.jobs <- job{"Del", v.Name, IP}
			logger.Info("Removed " + IP + " from " + v.Name)
		}
		// Delete all entries with old ip addresses
		Ips := IPSET.mac2ip(ctx, Mac, v)
		for _, i := range Ips {
			IPSET.jobs <- job{"Del", v.Name, i}
			logger.Info("Removed " + i + " from " + v.Name)
		}
	}
	// Add to the new ipset session
	IPSET.jobs <- job{"Add", "pfsession_" + Type + "_" + Network, IP + "," + Mac}
	logger.Info("Added " + IP + " " + Mac + " to pfsession_" + Type + "_" + Network)
	if Type == "Reg" {
		// Add to the ip ipset session
		IPSET.jobs <- job{"Add", "PF-iL2_ID" + Catid + "_" + Network, IP}
		logger.Info("Added " + IP + " to PF-iL2_ID" + Catid + "_" + Network)
	}
}

func handleMarkIpL2(res http.ResponseWriter, req *http.Request) {
	ctx := req.Context()

	IPSET := pfIPSETFromContext(req.Context())
	vars := mux.Vars(req)
	IP := vars["ip"]
	Network := vars["network"]
	Catid := vars["category_id"]
	Local := req.URL.Query().Get("local")

	// Update locally
	IPSET.IPSEThandleMarkIpL2(ctx, IP, Network, Catid)

	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterMarkIpL3(req.Context(), IP, Network, Catid)
	}
	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
}

func (IPSET *pfIPSET) IPSEThandleMarkIpL2(ctx context.Context, IP string, Network string, Catid string) {
	IPSET.jobs <- job{"Add", "PF-iL2_ID" + Catid + "_" + Network, IP}
}

func handleMarkIpL3(res http.ResponseWriter, req *http.Request) {
	ctx := req.Context()

	IPSET := pfIPSETFromContext(req.Context())
	vars := mux.Vars(req)
	IP := vars["ip"]
	Network := vars["network"]
	Catid := vars["category_id"]
	Local := req.URL.Query().Get("local")

	// Update locally
	IPSET.IPSEThandleMarkIpL3(ctx, IP, Network, Catid)

	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterMarkIpL3(req.Context(), IP, Network, Catid)
	}
	var result = map[string][]*Info{
		"result": {
			&Info{IP: IP, Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func (IPSET *pfIPSET) IPSEThandleMarkIpL3(ctx context.Context, IP string, Network string, Catid string) {
	IPSET.jobs <- job{"Add", "PF-iL3_ID" + Catid + "_" + Network, IP}
}

func handleLayer3(res http.ResponseWriter, req *http.Request) {
	ctx := req.Context()

	IPSET := pfIPSETFromContext(req.Context())
	vars := mux.Vars(req)
	IP := vars["ip"]
	Network := vars["network"]
	Type := vars["type"]
	Catid := vars["category_id"]
	Local := req.URL.Query().Get("local")

	// Update locally
	IPSET.IPSEThandleLayer3(ctx, IP, Network, Type, Catid)

	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterL3(req.Context(), IP, Network, Type, Catid)
	}

	var result = map[string][]*Info{
		"result": {
			&Info{IP: IP, Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func (IPSET *pfIPSET) IPSEThandleLayer3(ctx context.Context, IP string, Network string, Type string, Catid string) {
	logger := log.LoggerWContext(ctx)

	// Delete all entries with the new ip address
	for _, v := range IPSET.ListALL {
		r := ipset.Test(v.Name, IP)
		if r == nil {
			IPSET.jobs <- job{"Del", v.Name, IP}
			logger.Info("Removed " + IP + " from " + v.Name)
		}
	}
	// Add to the new ipset session
	IPSET.jobs <- job{"Add", "pfsession_" + Type + "_" + Network, IP}
	logger.Info("Added " + IP + " to pfsession_" + Type + "_" + Network)
	if Type == "Reg" {
		// Add to the ip ipset session
		IPSET.jobs <- job{"Add", "PF-iL3_ID" + Catid + "_" + Network, IP}
		logger.Info("Added " + IP + " to PF-iL3_ID" + Catid + "_" + Network)
	}
}

func (IPSET *pfIPSET) handleUnmarkMac(res http.ResponseWriter, req *http.Request) {
	ctx := req.Context()
	logger := log.LoggerWContext(ctx)

	vars := mux.Vars(req)
	Mac := vars["mac"]
	Local := req.URL.Query().Get("local")

	for _, v := range IPSET.ListALL {
		Ips := IPSET.mac2ip(req.Context(), Mac, v)
		for _, i := range Ips {
			IPSET.jobs <- job{"Del", v.Name, i}
			conn, _ := conntrack.New()
			conn.DeleteConnectionBySrcIp(i)
			logger.Info(fmt.Sprintf("Removed %s from %s", i, v.Name))
		}
	}
	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterUnmarkMac(req.Context(), Mac)
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

	vars := mux.Vars(req)
	IP := vars["ip"]
	Local := req.URL.Query().Get("local")

	for _, v := range IPSET.ListALL {
		r := ipset.Test(v.Name, IP)
		if r == nil {
			IPSET.jobs <- job{"Del", v.Name, IP}
			conn, _ := conntrack.New()
			conn.DeleteConnectionBySrcIp(IP)
			logger.Info(fmt.Sprintf("Removed %s from %s", IP, v.Name))
		}
	}
	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterUnmarkIp(req.Context(), IP)
	}
	var result = map[string][]*Info{
		"result": {
			&Info{IP: IP, Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}
