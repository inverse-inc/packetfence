package main

import (
	"github.com/coredns/coredns/core/dnsserver"
	"github.com/coredns/coredns/coremain"
)

func init() {
	dnsserver.Directives = append(dnsserver.Directives, "pfdns")
	dnsserver.Directives = append(dnsserver.Directives, "logger")
}

func main() {
	coremain.Run()
}
