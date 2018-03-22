package pfipset

import (
	ipset "github.com/digineo/go-ipset"
)

type job struct {
	Method  string `json:"method"`
	Set     string `json:"set"`
	Message string `json:"message"`
}

func doWork(id int, jobe job) {
	if jobe.Method == "Add" {
		ipset.Add(jobe.Set, jobe.Message)
	}
	if jobe.Method == "Del" {
		ipset.Del(jobe.Set, jobe.Message)
	}
}
