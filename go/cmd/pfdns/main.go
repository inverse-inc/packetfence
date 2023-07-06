package main

import (
	"fmt"
	"os"

	"github.com/coredns/coredns/core/dnsserver"
	"github.com/coredns/coredns/coremain"
	"github.com/coreos/go-systemd/daemon"
)

func init() {
	dnsserver.Directives = insertBefore(dnsserver.Directives, searchIndex(dnsserver.Directives, "forward"), "pfdns")
	dnsserver.Directives = insertBefore(dnsserver.Directives, searchIndex(dnsserver.Directives, "log")+1, "logger")
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

func insertBefore(a []string, index int, value string) []string {
	if index == -1 {
		return a
	}
	if len(a) == index { // nil or empty slice or after last element
		return append(a, value)
	}
	a = append(a[:index+1], a[index:]...) // index < len(a)
	a[index] = value
	return a
}

func searchIndex(a []string, value string) int {
	for i, s := range a {
		if s == value {
			return i
		}
	}
	return -1
}
