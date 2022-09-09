package main

import (
	"github.com/coredns/coredns/core/dnsserver"
	"github.com/coredns/coredns/coremain"
)

func init() {
	dnsserver.Directives = append(dnsserver.Directives, "pfdns")
}

func main() {
	coremain.Run()
}
