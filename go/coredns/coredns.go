package main

//go:generate go run directives_generate.go

import "github.com/inverse-inc/packetfence/go/coredns/coremain"

func main() {
	coremain.Run()
}
