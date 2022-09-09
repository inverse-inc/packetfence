package main

import (
        _ "github.com/coredns/example"

        "github.com/coredns/coredns/coremain"
        "github.com/coredns/coredns/core/dnsserver"
)

var directives = []string{
        "example",
        "whoami",
        "startup",
        "shutdown",
}

func init() {
        dnsserver.Directives = directives
}

func main() {
        coremain.Run()
}

