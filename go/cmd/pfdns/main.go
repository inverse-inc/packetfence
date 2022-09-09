package main

import (
        "github.com/coredns/coredns/coremain"
        "github.com/coredns/coredns/core/dnsserver"
)

func init() {
        dnsserver.Directives = append(dnsserver.Directives, "pfdns");
}

func main() {
        coremain.Run()
}

