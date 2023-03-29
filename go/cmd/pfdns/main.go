package main

import (
	"os"
	"fmt"

	"github.com/coredns/coredns/core/dnsserver"
	"github.com/coredns/coredns/coremain"
	"github.com/coreos/go-systemd/daemon"
)

func init() {
	dnsserver.Directives = append(dnsserver.Directives, "pfdns")
	dnsserver.Directives = append(dnsserver.Directives, "logger")
}

func main() {
	_, err := daemon.SdNotify(true, "READY=1")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error sending systemd ready notification %s\n", err.Error())
	}
	coremain.Run()
}

