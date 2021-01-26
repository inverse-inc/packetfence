package main

//go:generate go run directives_generate.go
//go:generate go run owners_generate.go

import (
	_ "github.com/inverse-inc/packetfence/go/coredns/core/plugin" // Plug in CoreDNS.
	"github.com/inverse-inc/packetfence/go/coredns/coremain"
)

func main() {
	coremain.Run()
}
