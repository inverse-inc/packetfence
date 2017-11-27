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
	Ip     string `json:"IP"`
}

func handlePassthrough(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	Ip := vars["ip"]
	Port := vars["port"]
	Local := vars["local"]

	ipset.Add("pfsession_passthrough", Ip+","+Port)
	if Local == "0" {
		updateClusterPassthrough(Ip, Port)
	}
	var result = map[string][]*Info{
		"result": {
			&Info{Ip: Ip, Status: "ACK"},
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
	Ip := vars["ip"]
	Port := vars["port"]
	Local := vars["local"]

	ipset.Add("pfsession_isol_passthrough", Ip+","+Port)
	if Local == "0" {
		updateClusterPassthroughIsol(Ip, Port)
	}
	var result = map[string][]*Info{
		"result": {
			&Info{Ip: Ip, Status: "ACK"},
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
	Ip := vars["ip"]
	Mac := vars["mac"]
	Network := vars["network"]
	Type := vars["type"]
	Catid := vars["catid"]
	Local := vars["local"]

	var all []ipset.IPSet
	all, _ = ipset.ListAll()

	for _, v := range all {
		// Delete all entries with the new ip address
		r := ipset.Test(v.Name, Ip)
		if r == nil {
			ipset.Del(v.Name, Ip)
			fmt.Println("Removed " + Ip + " from " + v.Name)
		}
		// Delete all entries with old ip addresses
		Ips := mac2ip(Mac)
		for _, i := range Ips {
			r = ipset.Test(v.Name, i)
			if r == nil {
				ipset.Del(v.Name, i)
				fmt.Println("Removed " + i + " from " + v.Name)
			}
		}
	}
	// Add to the new ipset session
	ipset.Add("pfsession_"+Type+"_"+Network, Ip+","+Mac)
	fmt.Println("Added " + Ip + " " + Mac + " to pfsession_" + Type + "_" + Network)
	if Type == "Reg" {
		// Add to the ip ipset session
		ipset.Add("PF-iL2_ID"+Catid+"_"+Network, Ip)
		fmt.Println("Added " + Ip + " to PF-iL2_ID" + Catid + "_" + Network)
	}
	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterL2(Ip, Mac, Network, Type, Catid)
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

func handleMarkIpL2(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	Ip := vars["ip"]
	Network := vars["network"]
	Catid := vars["catid"]
	Local := vars["local"]
	ipset.Add("PF-iL2_ID"+Catid+"_"+Network, Ip)
	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterMarkIpL3(Ip, Network, Catid)
	}
	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
}

func handleMarkIpL3(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	Ip := vars["ip"]
	Network := vars["network"]
	Catid := vars["catid"]
	Local := vars["local"]

	ipset.Add("PF-iL3_ID"+Catid+"_"+Network, Ip)
	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterMarkIpL3(Ip, Network, Catid)
	}
	var result = map[string][]*Info{
		"result": {
			&Info{Ip: Ip, Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func handleLayer3(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	Ip := vars["ip"]
	Network := vars["network"]
	Type := vars["type"]
	Catid := vars["catid"]
	Local := vars["local"]

	var all []ipset.IPSet
	all, _ = ipset.ListAll()
	// Delete all entries with the new ip address
	for _, v := range all {
		r := ipset.Test(v.Name, Ip)
		if r == nil {
			ipset.Del(v.Name, Ip)
			fmt.Println("Removed " + Ip + " from " + v.Name)
		}
	}
	// Add to the new ipset session
	ipset.Add("pfsession_"+Type+"_"+Network, Ip)
	fmt.Println("Added " + Ip + " to pfsession_" + Type + "_" + Network)
	if Type == "Reg" {
		// Add to the ip ipset session
		ipset.Add("PF-iL3_ID"+Catid+"_"+Network, Ip)
		fmt.Println("Added " + Ip + " to PF-iL3_ID" + Catid + "_" + Network)
	}
	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterL3(Ip, Network, Type, Catid)
	}

	var result = map[string][]*Info{
		"result": {
			&Info{Ip: Ip, Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}

func handleUnmarkMac(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	Mac := vars["mac"]
	Local := vars["local"]

	Ips := mac2ip(Mac)
	for _, i := range Ips {
		var all []ipset.IPSet
		all, _ = ipset.ListAll()

		for _, v := range all {
			r := ipset.Test(v.Name, i)
			if r == nil {
				ipset.Del(v.Name, i)
				conn, _ := conntrack.New()
				conn.DeleteConnectionBySrcIp(i)
				fmt.Println("Removed " + i + " from " + v.Name)
			}
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

func handleUnmarkIp(res http.ResponseWriter, req *http.Request) {
	vars := mux.Vars(req)
	Ip := vars["ip"]
	Local := vars["local"]

	var all []ipset.IPSet
	all, _ = ipset.ListAll()

	for _, v := range all {
		r := ipset.Test(v.Name, Ip)
		if r == nil {
			ipset.Del(v.Name, Ip)
			conn, _ := conntrack.New()
			conn.DeleteConnectionBySrcIp(Ip)
			fmt.Println("Removed " + Ip + " from " + v.Name)
		}
	}
	// Do we have to update the other members of the cluster
	if Local == "0" {
		updateClusterUnmarkIp(Ip)
	}
	var result = map[string][]*Info{
		"result": {
			&Info{Ip: Ip, Status: "ACK"},
		},
	}

	res.Header().Set("Content-Type", "application/json; charset=UTF-8")
	res.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(res).Encode(result); err != nil {
		panic(err)
	}
}
