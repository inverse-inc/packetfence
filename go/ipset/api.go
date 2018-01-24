package main

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/diegoguarnieri/go-conntrack/conntrack"
	"github.com/fdurand/go-ipset"
	"github.com/gorilla/mux"
)

type Info struct {
	Status string `json:"status"`
	Mac    string `json:"MAC"`
	IP     string `json:"IP"`
}

func handlePassthrough(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	IP := vars["ip"]
	Port := vars["port"]
	Local := vars["local"]

	ipset.Add("pfsession_passthrough", IP+","+Port)
	if Local == "0" {
		updateClusterPassthrough(IP, Port)
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
	vars := mux.Vars(req)
	IP := vars["ip"]
	Port := vars["port"]
	Local := vars["local"]

	ipset.Add("pfsession_isol_passthrough", IP+","+Port)
	if Local == "0" {
		updateClusterPassthroughIsol(IP, Port)
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
	vars := mux.Vars(req)
	IP := vars["ip"]
	Mac := vars["mac"]
	Network := vars["network"]
	Type := vars["type"]
	Catid := vars["catid"]
	Local := vars["local"]

	// Update locally
	IPSET.IPSEThandleLayer2(IP, Mac, Network, Type, Catid)

	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterL2(IP, Mac, Network, Type, Catid)
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

func (IPSET *pfIPSET) IPSEThandleLayer2(IP string, Mac string, Network string, Type string, Catid string) {

	for _, v := range IPSET.ListALL {
		// Delete all entries with the new ip address
		r := ipset.Test(v.Name, IP)
		if r == nil {
			ipset.Del(v.Name, IP)
			fmt.Println("Removed " + IP + " from " + v.Name)
		}
		// // Delete all entries with old ip addresses
		Ips := IPSET.mac2ip(Mac, v)
		for _, i := range Ips {
			// r = ipset.Test(v.Name, i)
			// if r == nil {
			ipset.Del(v.Name, i)
			fmt.Println("Removed " + i + " from " + v.Name)
			// }
		}
	}
	// Add to the new ipset session
	ipset.Add("pfsession_"+Type+"_"+Network, IP+","+Mac)
	fmt.Println("Added " + IP + " " + Mac + " to pfsession_" + Type + "_" + Network)
	if Type == "Reg" {
		// Add to the ip ipset session
		ipset.Add("PF-iL2_ID"+Catid+"_"+Network, IP)
		fmt.Println("Added " + IP + " to PF-iL2_ID" + Catid + "_" + Network)
	}
}

func handleMarkIpL2(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	IP := vars["ip"]
	Network := vars["network"]
	Catid := vars["catid"]
	Local := vars["local"]

	// Update locally
	IPSET.IPSEThandleMarkIpL2(IP, Network, Catid)

	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterMarkIpL3(IP, Network, Catid)
	}
	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
}

func (IPSET *pfIPSET) IPSEThandleMarkIpL2(IP string, Network string, Catid string) {
	ipset.Add("PF-iL2_ID"+Catid+"_"+Network, IP)
}

func handleMarkIpL3(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	IP := vars["ip"]
	Network := vars["network"]
	Catid := vars["catid"]
	Local := vars["local"]

	// Update locally
	IPSET.IPSEThandleMarkIpL3(IP, Network, Catid)

	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterMarkIpL3(IP, Network, Catid)
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

func (IPSET *pfIPSET) IPSEThandleMarkIpL3(IP string, Network string, Catid string) {
	ipset.Add("PF-iL3_ID"+Catid+"_"+Network, IP)
}

func handleLayer3(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	IP := vars["ip"]
	Network := vars["network"]
	Type := vars["type"]
	Catid := vars["catid"]
	Local := vars["local"]

	// Update locally
	IPSET.IPSEThandleLayer3(IP, Network, Type, Catid)

	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterL3(IP, Network, Type, Catid)
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

func (IPSET *pfIPSET) IPSEThandleLayer3(IP string, Network string, Type string, Catid string) {

	// Delete all entries with the new ip address
	for _, v := range IPSET.ListALL {
		r := ipset.Test(v.Name, IP)
		if r == nil {
			ipset.Del(v.Name, IP)
			fmt.Println("Removed " + IP + " from " + v.Name)
		}
	}
	// Add to the new ipset session
	ipset.Add("pfsession_"+Type+"_"+Network, IP)
	fmt.Println("Added " + IP + " to pfsession_" + Type + "_" + Network)
	if Type == "Reg" {
		// Add to the ip ipset session
		ipset.Add("PF-iL3_ID"+Catid+"_"+Network, IP)
		fmt.Println("Added " + IP + " to PF-iL3_ID" + Catid + "_" + Network)
	}
}

func (IPSET *pfIPSET) handleUnmarkMac(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	Mac := vars["mac"]
	Local := vars["local"]

	for _, v := range IPSET.ListALL {
		Ips := IPSET.mac2ip(Mac, v)
		for _, i := range Ips {
			// r := ipset.Test(v.Name, i)
			// if r == nil {
			ipset.Del(v.Name, i)
			conn, _ := conntrack.New()
			conn.DeleteConnectionBySrcIp(i)
			fmt.Println("Removed " + i + " from " + v.Name)
			// }
		}
	}
	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterUnmarkMac(Mac)
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
	vars := mux.Vars(req)
	IP := vars["ip"]
	Local := vars["local"]

	for _, v := range IPSET.ListALL {
		r := ipset.Test(v.Name, IP)
		if r == nil {
			ipset.Del(v.Name, IP)
			conn, _ := conntrack.New()
			conn.DeleteConnectionBySrcIp(IP)
			fmt.Println("Removed " + IP + " from " + v.Name)
		}
	}
	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterUnmarkIp(IP)
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
