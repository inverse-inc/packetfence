package pfipset

import (
	ipset "github.com/inverse-inc/go-ipset"
)

type job struct {
	Method  string
	Set     string
	Message string
}

func doWork(id int, jobe job) {
	if jobe.Method == "Add" {
		ipset.Add(jobe.Set, jobe.Message)
	}
	if jobe.Method == "Del" {
		ipset.Del(jobe.Set, jobe.Message)
	}
}
