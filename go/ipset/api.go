package main

import (
	"fmt"
	"net/http"

	"github.com/digineo/go-ipset"
	"github.com/gorilla/mux"
)

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
		r := ipset.Test(v.Name, Ip)
		if r == nil {
			ipset.Del(v.Name, Ip)
			fmt.Println("Removed " + Ip + " from " + v.Name)
		}
	}
	ipset.Add("pfsession_"+Type+"_"+Network, Ip+","+Mac)
	fmt.Println("Added " + Ip + " " + Mac + " to pfsession_" + Type + "_" + Network)
	if Type == "Reg" {
		ipset.Add("PF-iL2_ID"+Catid+"_"+Network, Ip)
		fmt.Println("Added " + Ip + " to PF-iL2_ID" + Catid + "_" + Network)
	}

	if Local == "0" {
		updateClusterL2(Ip, Mac, Network, Type, Catid)
	}
	res.Write([]byte("Updated!\n"))
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

	for _, v := range all {
		r := ipset.Test(v.Name, Ip)
		if r == nil {
			ipset.Del(v.Name, Ip)
			fmt.Println("Removed " + Ip + " from " + v.Name)
		}
	}
	ipset.Add("pfsession_"+Type+"_"+Network, Ip)
	fmt.Println("Added " + Ip + " to pfsession_" + Type + "_" + Network)
	if Type == "Reg" {
		ipset.Add("PF-iL3_ID"+Catid+"_"+Network, Ip)
		fmt.Println("Added " + Ip + " to PF-iL3_ID" + Catid + "_" + Network)
	}
	if Local == "0" {
		updateClusterL3(Ip, Network, Type, Catid)
	}

	res.Write([]byte("Updated!\n"))
}
