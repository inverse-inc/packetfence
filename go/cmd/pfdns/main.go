package main

import (
	"fmt"
	"os"

	"github.com/coredns/coredns/core/dnsserver"
	"github.com/coredns/coredns/coremain"
	"github.com/coreos/go-systemd/daemon"
)

func init() {
	dnsserver.Directives = append([]string{"pfdns", "logger"}, dnsserver.Directives...)
}

func main() {
	_, err := daemon.SdNotify(true, "READY=1")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error sending systemd ready notification %s\n", err.Error())
	}
	defer func() {
		_, err := daemon.SdNotify(false, "STOPPING=1")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error sending systemd stopping notification %s\n", err.Error())
		}
	}()
	coremain.Run()
}
